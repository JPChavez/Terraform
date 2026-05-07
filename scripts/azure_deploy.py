#!/usr/bin/env python3
"""
azure_deploy.py — Pipeline de despliegue de Terraform en Azure (equivalente Python del workflow YAML).

Replica la lógica de .github/workflows/azure-terraform-deploy.yml en cinco etapas:

  Etapa 1 → Escaneo de secretos  (gitleaks)
  Etapa 2 → Validación y linting (fmt / init / validate / tflint / checkov)
  Etapa 3 → Plan                 (terraform plan + detección de destrucciones)
  Etapa 4 → Puerta anti-destroy  (bloquea si hay recursos a eliminar sin confirmación)
  Etapa 5 → Apply                (terraform apply con confirmación interactiva o CI)

Uso:
  python scripts/azure_deploy.py                      # pipeline completo, env=dev
  python scripts/azure_deploy.py --env uat            # entorno UAT
  python scripts/azure_deploy.py --force-destroy yes  # permitir destrucciones
  python scripts/azure_deploy.py --plan-only          # solo hasta la etapa de plan
  python scripts/azure_deploy.py --skip-secrets-scan  # omitir gitleaks

Autenticación con Azure (establecer antes de ejecutar):
  export ARM_CLIENT_ID=<app-id>
  export ARM_TENANT_ID=<tenant-id>
  export ARM_SUBSCRIPTION_ID=<subscription-id>
  export ARM_USE_OIDC=true
  # O simplemente: az login
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


# ══════════════════════════════════════════════════════════════════════════════
# Helpers de color ANSI (sin dependencias externas)
# ══════════════════════════════════════════════════════════════════════════════

RED    = "\033[91m"
YELLOW = "\033[93m"
GREEN  = "\033[92m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"


def _color(msg: str, color: str) -> str:
    """Aplica color ANSI solo cuando la salida es una terminal (no en pipes/CI logs)."""
    return f"{color}{msg}{RESET}" if sys.stdout.isatty() else msg


def info(msg: str)    -> None: print(_color(f"i  {msg}", CYAN))
def success(msg: str) -> None: print(_color(f"OK {msg}", GREEN))
def warn(msg: str)    -> None: print(_color(f"!  {msg}", YELLOW))
def error(msg: str)   -> None: print(_color(f"!! {msg}", RED), file=sys.stderr)


# ══════════════════════════════════════════════════════════════════════════════
# Ejecutor de comandos
# ══════════════════════════════════════════════════════════════════════════════

def run(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    capture: bool = False,
    extra_env: dict | None = None,
) -> subprocess.CompletedProcess:
    """
    Ejecuta un comando externo via subprocess.

    Parámetros:
        cmd       : Lista de tokens del comando, p.ej. ["terraform", "init"].
        cwd       : Directorio de trabajo donde se ejecuta el comando.
        check     : Si es True, lanza CalledProcessError en código de salida != 0.
        capture   : Si es True, captura stdout/stderr en lugar de mostrarlos en pantalla.
        extra_env : Variables de entorno adicionales que se fusionan con os.environ.

    Retorna el objeto CompletedProcess para que el llamador pueda inspeccionar
    returncode, stdout y stderr.
    """
    # Fusionar el entorno actual con cualquier variable extra que se pase.
    merged_env = {**os.environ, **(extra_env or {})}

    # Mostrar el comando que se va a ejecutar (facilita la depuración).
    print(_color(f"  $ {' '.join(str(t) for t in cmd)}", BOLD))

    return subprocess.run(
        cmd,
        cwd=cwd,
        check=check,
        capture_output=capture,
        text=True,          # decodificar stdout/stderr como str (no bytes)
        env=merged_env,
    )


def stage(name: str) -> None:
    """Imprime una cabecera de etapa claramente visible para separar la salida del pipeline."""
    sep = "─" * 60
    print(f"\n{_color(sep, CYAN)}")
    print(_color(f"  {name}", BOLD + CYAN))
    print(_color(sep, CYAN))


# ══════════════════════════════════════════════════════════════════════════════
# Etapa 1: Escaneo de secretos
# ══════════════════════════════════════════════════════════════════════════════

def scan_secrets(repo_root: Path) -> None:
    """
    Ejecuta gitleaks sobre el repositorio para detectar secretos comprometidos.

    Replica el job 'secrets-scan' del workflow YAML.

    - Si gitleaks no está instalado se emite una advertencia y la etapa se omite,
      para no bloquear a desarrolladores que no lo tengan localmente.
    - En CI (GitHub Actions) gitleaks se instala explícitamente antes de ejecutar
      este script.
    - La opción --redact sustituye los valores de secretos encontrados por
      REDACTED en la salida, evitando exponerlos en logs.
    - La opción --no-git escanea los archivos del directorio de trabajo en lugar
      del historial de git (más rápido y suficiente para el caso de uso).
    """
    stage("Etapa 1 — Escaneo de Secretos (gitleaks)")

    # Verificar si el binario gitleaks está disponible en el PATH.
    resultado = run(["which", "gitleaks"], check=False, capture=True)
    if resultado.returncode != 0:
        warn("gitleaks no encontrado en PATH — omitiendo escaneo de secretos.")
        warn("Instalacion: https://github.com/gitleaks/gitleaks#installing")
        return

    # Construir el comando base.
    cmd = [
        "gitleaks", "detect",
        "--source", str(repo_root),
        "--redact",    # ocultar valores reales de secretos en la salida
        "--no-git",    # escanear archivos directamente, no el historial git
    ]

    # Agregar el archivo de configuración si existe en el repositorio.
    config = repo_root / ".gitleaks.toml"
    if config.exists():
        cmd += ["--config", str(config)]

    run(cmd, cwd=repo_root)
    success("Sin secretos detectados.")


# ══════════════════════════════════════════════════════════════════════════════
# Etapa 2: Validación y linting
# ══════════════════════════════════════════════════════════════════════════════

def validate(working_dir: Path, env_name: str) -> None:
    """
    Ejecuta la suite completa de validación sobre el código Terraform.

    Pasos (replica el job 'validate' del YAML):
      2a. terraform fmt -check -recursive   — verificación de formato (sin escritura)
      2b. terraform init                    — inicializar backend y proveedores
      2c. terraform validate                — verificación de sintaxis y tipos
      2d. tflint --init && tflint --recursive — linting de reglas del proveedor
      2e. checkov                           — escaneo de seguridad y cumplimiento
    """
    stage("Etapa 2 — Validacion y Linting")

    # ── 2a. Verificación de formato ───────────────────────────────────────────
    # -check sale con código != 0 si algún archivo no está formateado.
    # NO modifica archivos; solo informa — use 'terraform fmt -recursive' para corregir.
    info("Verificando formato de Terraform ...")
    run(["terraform", "fmt", "-check", "-recursive"], cwd=working_dir)
    success("Verificacion de formato correcta.")

    # ── 2b. Terraform init ────────────────────────────────────────────────────
    # La clave del backend codifica la nube + entorno para que cada entorno use
    # su propio archivo de estado dentro del contenedor de Azure Blob Storage compartido.
    info("Inicializando backend de Terraform ...")
    backend_key = f"azure/{env_name}.terraform.tfstate"
    run(
        ["terraform", "init", f"-backend-config=key={backend_key}"],
        cwd=working_dir,
    )
    success("terraform init completado.")

    # ── 2c. Terraform validate ────────────────────────────────────────────────
    # Verifica que la configuración sea sintácticamente válida y coherente.
    # No requiere credenciales cloud para ejecutarse.
    info("Validando configuracion de Terraform ...")
    run(["terraform", "validate"], cwd=working_dir)
    success("terraform validate correcto.")

    # ── 2d. tflint ────────────────────────────────────────────────────────────
    # tflint aplica reglas específicas del proveedor (plugin azurerm v0.27.0).
    # --init descarga el plugin definido en .tflint.hcl la primera vez que se ejecuta.
    info("Ejecutando tflint ...")
    run(["tflint", "--init"], cwd=working_dir)
    run(["tflint", "--recursive"], cwd=working_dir)
    success("tflint correcto.")

    # ── 2e. Escaneo de seguridad con checkov ──────────────────────────────────
    # Versión fijada a 3.2.0 para coincidir con CI.
    # Produce un archivo SARIF para subirlo a GitHub Advanced Security.
    info("Ejecutando escaneo de seguridad con checkov ...")
    sarif_path = working_dir / "results.sarif"

    # Primera pasada: generar SARIF (para dashboards de seguridad de GitHub).
    # check=False porque checkov devuelve código != 0 cuando hay hallazgos de política,
    # pero queremos que la segunda pasada sea el resultado autoritativo.
    run(
        [
            "checkov", "-d", ".",
            "--framework", "terraform",
            "--output", "sarif",
            "--output-file-path", str(sarif_path),
        ],
        cwd=working_dir,
        check=False,
    )

    # Segunda pasada: salida compacta legible por humanos — esta pasada determina pass/fail.
    run(
        ["checkov", "-d", ".", "--framework", "terraform", "--quiet", "--compact"],
        cwd=working_dir,
    )
    success("Escaneo checkov correcto.")


# ══════════════════════════════════════════════════════════════════════════════
# Etapa 3: Plan
# ══════════════════════════════════════════════════════════════════════════════

def plan(working_dir: Path, env_name: str) -> tuple[Path, int]:
    """
    Ejecuta terraform plan y cuenta cuántos recursos serán destruidos.

    Replica el job 'plan-dev' del YAML, incluyendo el paso de detección de
    destrucciones que imprime una advertencia cuando se encuentran eliminaciones.

    Retorna:
        (ruta_del_plan, cantidad_de_destrucciones)
    """
    stage("Etapa 3 — Terraform Plan")

    # ── 3a. Re-inicializar antes del plan ─────────────────────────────────────
    # En el YAML esto es un job separado; re-init antes de plan es buena práctica
    # para asegurarse de que el backend y los providers estén actualizados.
    backend_key = f"azure/{env_name}.terraform.tfstate"
    run(
        ["terraform", "init", f"-backend-config=key={backend_key}"],
        cwd=working_dir,
    )

    # ── 3b. terraform plan ────────────────────────────────────────────────────
    # -out guarda el plan binario para que apply lo consuma exactamente;
    # garantiza que lo que se aprueba es lo que se aplica.
    plan_file = working_dir / f"{env_name}.tfplan"
    vars_file  = f"{env_name}.tfvars"

    info(f"Ejecutando terraform plan (env={env_name}) ...")
    run(
        [
            "terraform", "plan",
            f"-var-file={vars_file}",
            f"-out={plan_file.name}",
        ],
        cwd=working_dir,
    )

    # ── 3c. Convertir el plan a texto legible para detectar destrucciones ─────
    # 'terraform show' renderiza el plan binario en texto legible.
    resultado = run(
        ["terraform", "show", "-no-color", plan_file.name],
        cwd=working_dir,
        capture=True,
        check=False,
    )
    plan_text = resultado.stdout

    # ── 3d. Contar recursos marcados para destrucción ─────────────────────────
    # terraform show etiqueta cada recurso destruido con "# <nombre> will be destroyed".
    destroy_count = len(re.findall(r"# .+ will be destroyed", plan_text))

    if destroy_count > 0:
        warn(f"{destroy_count} recurso(s) seran DESTRUIDOS por este plan.")
        # Mostrar exactamente qué recursos serán eliminados.
        for linea in plan_text.splitlines():
            if "will be destroyed" in linea:
                warn(f"  {linea.strip()}")
    else:
        success("Ningun recurso sera destruido.")

    success(f"Plan guardado en {plan_file.name}")
    return plan_file, destroy_count


# ══════════════════════════════════════════════════════════════════════════════
# Etapa 4: Puerta de protección anti-destroy
# ══════════════════════════════════════════════════════════════════════════════

def destroy_gate(destroy_count: int, force_destroy: str) -> None:
    """
    Bloquea el pipeline cuando el plan contiene destrucciones, a menos que el
    ejecutor haya reconocido explícitamente el riesgo pasando --force-destroy yes.

    Replica el job 'destroy-gate' del YAML.

    En el YAML este es un job separado que descarga el artefacto del plan;
    aquí es una verificación en proceso usando el destroy_count ya calculado
    en la etapa de plan, evitando pasos de serialización innecesarios.
    """
    stage("Etapa 4 — Puerta de Proteccion Anti-Destroy")

    info(f"Destrucciones detectadas: {destroy_count} | force_destroy: '{force_destroy}'")

    if destroy_count > 0 and force_destroy.lower() != "yes":
        error(
            f"PROTECCION ANTI-DESTROY: {destroy_count} recurso(s) serian destruidos.\n"
            "  Vuelva a ejecutar con --force-destroy yes para confirmar."
        )
        sys.exit(1)

    success(f"Puerta anti-destroy superada (destrucciones={destroy_count}, force={force_destroy}).")


# ══════════════════════════════════════════════════════════════════════════════
# Etapa 5: Apply
# ══════════════════════════════════════════════════════════════════════════════

def apply(working_dir: Path, plan_file: Path, env_name: str) -> None:
    """
    Aplica el archivo de plan generado previamente.

    El pipeline YAML protege este paso con un GitHub Environment que requiere
    aprobación de Juan Pablo Chavez antes de ejecutarse (environment: dev).
    En este script el equivalente es un prompt de confirmación interactivo cuando
    stdin es una terminal; en CI (stdin no es TTY) procede automáticamente.

    Replica el job 'apply-dev' del YAML.
    """
    stage("Etapa 5 — Terraform Apply")

    # Re-init para garantizar que los providers y el backend estén listos antes del apply.
    backend_key = f"azure/{env_name}.terraform.tfstate"
    run(
        ["terraform", "init", f"-backend-config=key={backend_key}"],
        cwd=working_dir,
    )

    # ── Confirmación interactiva (equivalente al required-reviewer de GitHub) ──
    # Solo se solicita cuando stdin es una terminal (ejecución local).
    # En CI (stdin no es TTY) se salta y procede automáticamente.
    if sys.stdin.isatty():
        print()
        respuesta = input(
            _color("  A punto de aplicar cambios en Azure. Continuar? [yes/N]: ", YELLOW)
        ).strip()
        if respuesta.lower() != "yes":
            warn("Apply cancelado por el usuario.")
            sys.exit(0)

    info(f"Aplicando plan {plan_file.name} ...")
    # -auto-approve omite la confirmación interactiva de Terraform; el script
    # ya pidió confirmación al usuario en el paso anterior.
    run(
        ["terraform", "apply", "-auto-approve", plan_file.name],
        cwd=working_dir,
    )
    success("terraform apply completado — infraestructura actualizada.")


# ══════════════════════════════════════════════════════════════════════════════
# Validación de variables de entorno de autenticación
# ══════════════════════════════════════════════════════════════════════════════

def check_auth_env() -> None:
    """
    Verifica que las variables ARM necesarias para la autenticación OIDC con Azure
    estén presentes antes de intentar cualquier comando de Terraform.

    En GitHub Actions estas variables las establece automáticamente la action
    'azure/login@v2'. Para ejecución local, exportarlas antes del script:

        export ARM_CLIENT_ID=<app-id>
        export ARM_TENANT_ID=<tenant-id>
        export ARM_SUBSCRIPTION_ID=<subscription-id>
        export ARM_USE_OIDC=true

    Alternativa local: ejecutar 'az login' antes de correr este script;
    el proveedor azurerm detectará las credenciales del CLI automáticamente.
    """
    required = ["ARM_CLIENT_ID", "ARM_TENANT_ID", "ARM_SUBSCRIPTION_ID"]
    missing  = [v for v in required if not os.getenv(v)]

    if missing:
        error(
            "Variables de entorno faltantes: " + ", ".join(missing) + "\n"
            "  Configuralas o ejecuta 'az login' antes de correr este script.\n"
            "  Ver docstring de check_auth_env() para mas detalles."
        )
        sys.exit(1)


# ══════════════════════════════════════════════════════════════════════════════
# Interfaz de línea de comandos
# ══════════════════════════════════════════════════════════════════════════════

def parse_args() -> argparse.Namespace:
    """Define y parsea los argumentos del CLI."""
    parser = argparse.ArgumentParser(
        description="Pipeline de despliegue de Terraform en Azure (equivalente Python del workflow YAML).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--env",
        default="dev",
        choices=["dev", "uat", "prod"],
        help="Entorno destino (por defecto: dev).",
    )
    parser.add_argument(
        "--force-destroy",
        default="no",
        metavar="yes|no",
        help='Permitir cambios destructivos — pasar "yes" para omitir la proteccion anti-destroy.',
    )
    parser.add_argument(
        "--plan-only",
        action="store_true",
        help="Detener despues de la etapa de plan (sin apply).",
    )
    parser.add_argument(
        "--skip-secrets-scan",
        action="store_true",
        help="Omitir la etapa de escaneo de secretos con gitleaks.",
    )
    return parser.parse_args()


# ══════════════════════════════════════════════════════════════════════════════
# Punto de entrada principal
# ══════════════════════════════════════════════════════════════════════════════

def main() -> None:
    args = parse_args()

    # Localizar la raíz del repositorio y el directorio de trabajo azure/.
    # __file__ apunta a scripts/azure_deploy.py -> parent.parent es la raíz.
    repo_root   = Path(__file__).resolve().parent.parent
    working_dir = repo_root / "azure"

    if not working_dir.is_dir():
        error(f"Directorio azure/ no encontrado en {working_dir}")
        sys.exit(1)

    # Cabecera del pipeline.
    print(_color(f"\n{'=' * 60}", BOLD))
    print(_color(f"  Pipeline Azure Terraform  |  env={args.env}", BOLD))
    print(_color(f"{'=' * 60}\n", BOLD))

    # Verificar credenciales antes de hacer cualquier trabajo.
    check_auth_env()

    # ── Ejecutar cada etapa en secuencia ──────────────────────────────────────
    # Cada etapa falla con sys.exit(1) si encuentra un error, lo que detiene
    # el pipeline completo, igual que el comportamiento needs: del YAML.

    if not args.skip_secrets_scan:
        scan_secrets(repo_root)                              # Etapa 1

    validate(working_dir, args.env)                          # Etapa 2

    plan_file, destroy_count = plan(working_dir, args.env)   # Etapa 3

    # La puerta anti-destroy se evalúa incluso en modo --plan-only para dar
    # retroalimentación temprana sobre cambios riesgosos sin necesidad de apply.
    destroy_gate(destroy_count, args.force_destroy)          # Etapa 4

    if args.plan_only:
        warn("Flag --plan-only activo — omitiendo apply.")
        sys.exit(0)

    apply(working_dir, plan_file, args.env)                  # Etapa 5

    print()
    success("Pipeline finalizado exitosamente.")


if __name__ == "__main__":
    main()
