#!/usr/bin/env python3
"""
gcp_deploy.py — Pipeline de despliegue de Terraform en GCP (equivalente Python del workflow YAML).

Replica la lógica de .github/workflows/gcp-terraform-deploy.yml en cinco etapas:

  Etapa 1 → Escaneo de secretos  (gitleaks)
  Etapa 2 → Validación y linting (fmt / init / validate / tflint / checkov)
  Etapa 3 → Plan                 (terraform plan + detección de destrucciones)
  Etapa 4 → Puerta anti-destroy  (bloquea si hay recursos a eliminar sin confirmación)
  Etapa 5 → Apply                (terraform apply con confirmación interactiva o CI)

Diferencias clave respecto al script de Azure:
  - Autenticación: GCP usa Application Default Credentials (ADC) o GOOGLE_CREDENTIALS,
    en lugar de las variables ARM_* de Azure.
  - Backend: GCP usa un prefijo GCS (prefix=gcp/<env>) en lugar de una clave de blob.
  - Plugin de tflint: tflint-ruleset-google en vez de tflint-ruleset-azurerm.
  - Entorno de GitHub: 'gcp-dev' en el YAML; aquí se construye como 'gcp-<env>'.

Uso:
  python scripts/gcp_deploy.py                      # pipeline completo, env=dev
  python scripts/gcp_deploy.py --env uat            # entorno UAT
  python scripts/gcp_deploy.py --force-destroy yes  # permitir destrucciones
  python scripts/gcp_deploy.py --plan-only          # solo hasta la etapa de plan
  python scripts/gcp_deploy.py --skip-secrets-scan  # omitir gitleaks

Autenticación con GCP (una de las siguientes opciones antes de ejecutar):
  # Opción A — Application Default Credentials (recomendada para uso local):
  gcloud auth application-default login

  # Opción B — Service Account con JSON en variable de entorno:
  export GOOGLE_CREDENTIALS=$(cat /ruta/a/sa-key.json)

  # Opción C — Ruta al archivo JSON de la cuenta de servicio:
  export GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/sa-key.json
"""

import argparse
import json
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
    merged_env = {**os.environ, **(extra_env or {})}
    print(_color(f"  $ {' '.join(str(t) for t in cmd)}", BOLD))
    return subprocess.run(
        cmd,
        cwd=cwd,
        check=check,
        capture_output=capture,
        text=True,
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
    - La opción --redact sustituye los valores de secretos encontrados por
      REDACTED en la salida, evitando exponerlos en logs.
    - La opción --no-git escanea los archivos del directorio de trabajo en lugar
      del historial de git (más rápido para uso local).
    """
    stage("Etapa 1 — Escaneo de Secretos (gitleaks)")

    # Verificar si el binario gitleaks está disponible en el PATH.
    resultado = run(["which", "gitleaks"], check=False, capture=True)
    if resultado.returncode != 0:
        warn("gitleaks no encontrado en PATH — omitiendo escaneo de secretos.")
        warn("Instalacion: https://github.com/gitleaks/gitleaks#installing")
        return

    cmd = [
        "gitleaks", "detect",
        "--source", str(repo_root),
        "--redact",    # reemplazar valores de secretos con REDACTED
        "--no-git",    # escanear archivos directamente, no el historial git
    ]

    # Incluir configuración personalizada si existe en el repositorio.
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
    Ejecuta la suite completa de validación sobre el código Terraform de GCP.

    Pasos (replica el job 'validate' del YAML):
      2a. terraform fmt -check -recursive   — verificación de formato (sin escritura)
      2b. terraform init                    — inicializar backend GCS y proveedores
      2c. terraform validate                — verificación de sintaxis y tipos
      2d. tflint --init && tflint --recursive — linting con plugin tflint-ruleset-google
      2e. checkov                           — escaneo de seguridad y cumplimiento GCP

    El backend de GCP usa un prefijo en GCS (prefix=gcp/<env>) en lugar de una
    clave de blob como Azure; esto separa el estado por entorno dentro del
    bucket jproject-tfstate.
    """
    stage("Etapa 2 — Validacion y Linting")

    # ── 2a. Verificación de formato ───────────────────────────────────────────
    # -check sale con código != 0 si algún archivo no está formateado.
    # NO modifica archivos; solo informa.
    info("Verificando formato de Terraform ...")
    run(["terraform", "fmt", "-check", "-recursive"], cwd=working_dir)
    success("Verificacion de formato correcta.")

    # ── 2b. Terraform init ────────────────────────────────────────────────────
    # El prefijo del backend GCS sigue el patrón gcp/<env> para que cada
    # entorno tenga su propio directorio de estado en el bucket compartido.
    info("Inicializando backend de Terraform (GCS) ...")
    backend_prefix = f"gcp/{env_name}"
    run(
        ["terraform", "init", f"-backend-config=prefix={backend_prefix}"],
        cwd=working_dir,
    )
    success("terraform init completado.")

    # ── 2c. Terraform validate ────────────────────────────────────────────────
    info("Validando configuracion de Terraform ...")
    run(["terraform", "validate"], cwd=working_dir)
    success("terraform validate correcto.")

    # ── 2d. tflint ────────────────────────────────────────────────────────────
    # GCP usa el plugin tflint-ruleset-google (v0.28.0), configurado en
    # gcp/.tflint.hcl. --init descarga el plugin en el primer uso.
    info("Ejecutando tflint (plugin google) ...")
    run(["tflint", "--init"], cwd=working_dir)
    run(["tflint", "--recursive"], cwd=working_dir)
    success("tflint correcto.")

    # ── 2e. Escaneo de seguridad con checkov ──────────────────────────────────
    # Versión fijada a 3.2.0 para coincidir con CI.
    # La primera pasada genera SARIF para GitHub Advanced Security.
    # La segunda pasada produce la salida legible que determina pass/fail.
    info("Ejecutando escaneo de seguridad con checkov ...")
    sarif_path = working_dir / "results.sarif"

    # Primera pasada: SARIF (check=False porque checkov sale con != 0 en hallazgos).
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

    # Segunda pasada: salida compacta legible — esta determina pass/fail del pipeline.
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

    Replica el job 'plan-dev' del YAML, incluyendo la detección de destrucciones
    mediante análisis de texto del plan renderizado.

    Retorna:
        (ruta_del_plan, cantidad_de_destrucciones)
    """
    stage("Etapa 3 — Terraform Plan")

    # ── 3a. Re-inicializar antes del plan ─────────────────────────────────────
    backend_prefix = f"gcp/{env_name}"
    run(
        ["terraform", "init", f"-backend-config=prefix={backend_prefix}"],
        cwd=working_dir,
    )

    # ── 3b. terraform plan ────────────────────────────────────────────────────
    # -out guarda el plan binario; garantiza que apply ejecuta exactamente
    # lo que se aprobó, sin posibilidad de cambios entre plan y apply.
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
    # 'terraform show' convierte el plan binario en texto que podemos analizar.
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
        # Listar exactamente qué recursos serán eliminados para revisión.
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

    En el YAML este job descarga el artefacto del plan y lee destroy_count.txt;
    aquí es una verificación en proceso usando el valor ya calculado en plan(),
    evitando la serialización a disco.
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


# Aprobador requerido antes del apply — equivalente al required-reviewer del GitHub Environment.
# Solo esta persona puede autorizar cambios en infraestructura GCP.
REQUIRED_APPROVER = "Juan Pablo Chavez"

# Máximo de intentos para ingresar el nombre del aprobador antes de abortar.
MAX_APPROVAL_ATTEMPTS = 3


# ══════════════════════════════════════════════════════════════════════════════
# Etapa 5: Aprobación + Apply
# ══════════════════════════════════════════════════════════════════════════════

def request_approval(env_name: str) -> None:
    """
    Solicita aprobación explícita del aprobador autorizado antes del apply.

    Equivale al 'required reviewer' del GitHub Environment 'gcp-dev' en el YAML.
    El aprobador debe escribir su nombre completo exacto para continuar; cualquier
    otro valor — incluyendo errores de tipeo — aborta el pipeline.

    Se permiten hasta MAX_APPROVAL_ATTEMPTS intentos antes de cancelar automáticamente,
    para evitar bloqueos por errores de escritura sin sacrificar seguridad.

    En CI (stdin no es TTY) la etapa se salta: la aprobación la gestiona el
    GitHub Environment con su propio mecanismo de revisores requeridos.
    """
    stage("Etapa 5a — Aprobacion Requerida")

    # En CI no hay terminal interactiva — el GitHub Environment ya requirió aprobación.
    if not sys.stdin.isatty():
        info("Modo CI detectado (stdin no es TTY) — aprobacion gestionada por GitHub Environment.")
        return

    print()
    print(_color(f"  Aprobador requerido: {REQUIRED_APPROVER}", BOLD))
    print(_color(f"  Entorno destino    : {env_name}", BOLD))
    print()
    warn("Esta accion desplegara o modificara infraestructura real en GCP.")
    warn(f"Solo '{REQUIRED_APPROVER}' puede autorizar este apply.")
    print()

    for intento in range(1, MAX_APPROVAL_ATTEMPTS + 1):
        nombre = input(
            _color(
                f"  [{intento}/{MAX_APPROVAL_ATTEMPTS}] Escribe tu nombre completo para aprobar: ",
                YELLOW,
            )
        ).strip()

        if nombre == REQUIRED_APPROVER:
            # Nombre correcto — aprobación concedida.
            success(f"Apply aprobado por '{nombre}'.")
            return

        restantes = MAX_APPROVAL_ATTEMPTS - intento
        if restantes > 0:
            # Nombre incorrecto pero quedan intentos.
            warn(f"Nombre incorrecto. Intentos restantes: {restantes}.")
        else:
            # Se agotaron los intentos.
            error(
                f"Aprobacion fallida tras {MAX_APPROVAL_ATTEMPTS} intentos.\n"
                f"  Se esperaba: '{REQUIRED_APPROVER}'\n"
                "  Apply cancelado."
            )
            sys.exit(1)


def apply(working_dir: Path, plan_file: Path, env_name: str) -> None:
    """
    Solicita aprobación y aplica el archivo de plan generado previamente en GCP.

    El pipeline YAML protege este paso con el GitHub Environment 'gcp-dev',
    que requiere aprobación de Juan Pablo Chavez antes de ejecutarse.
    En este script la aprobación es explícita: el aprobador debe escribir
    su nombre completo exacto en request_approval() antes de continuar.

    Replica el job 'apply-dev' del YAML.
    """
    # Solicitar aprobación antes de tocar el backend o ejecutar apply.
    request_approval(env_name)

    stage("Etapa 5b — Terraform Apply")

    # Re-init para garantizar que backend y providers estén listos antes del apply.
    backend_prefix = f"gcp/{env_name}"
    run(
        ["terraform", "init", f"-backend-config=prefix={backend_prefix}"],
        cwd=working_dir,
    )

    info(f"Aplicando plan {plan_file.name} ...")
    # -auto-approve omite la confirmación interactiva propia de Terraform;
    # el script ya solicitó confirmación al usuario en el paso anterior.
    try:
        run(
            ["terraform", "apply", "-auto-approve", plan_file.name],
            cwd=working_dir,
        )
    except subprocess.CalledProcessError as exc:
        # GCP KeyRings cannot be deleted once created. If a KeyRing exists in GCP
        # but not in Terraform state (e.g. after state loss), import it and retry.
        output = (exc.stdout or "") + (exc.stderr or "")
        kr_match = re.search(
            r"Error 409.*?(projects/[^/]+/locations/[^/]+/keyRings/\S+?)(?:\.| already)",
            output,
        )
        if kr_match:
            kr_id = kr_match.group(1).rstrip(".")
            warn(f"KeyRing ya existe en GCP — importando al state: {kr_id}")
            run(
                ["terraform", "import", "google_kms_key_ring.main", kr_id],
                cwd=working_dir,
                check=False,
            )
            info("Reintentando apply tras importar KeyRing...")
            run(
                ["terraform", "apply", "-auto-approve", plan_file.name],
                cwd=working_dir,
            )
        else:
            raise
    success("terraform apply completado — infraestructura GCP actualizada.")


# ══════════════════════════════════════════════════════════════════════════════
# Validación de credenciales GCP
# ══════════════════════════════════════════════════════════════════════════════

def check_auth_env() -> None:
    """
    Verifica que haya credenciales GCP disponibles antes de intentar cualquier
    comando de Terraform que contacte la API de Google Cloud.

    GCP acepta credenciales de tres formas (en orden de precedencia):

      1. GOOGLE_CREDENTIALS (variable de entorno con el JSON de la SA en línea).
      2. GOOGLE_APPLICATION_CREDENTIALS (ruta a un archivo JSON de SA).
      3. Application Default Credentials — ADC (~/.config/gcloud/
         application_default_credentials.json), generadas con:
             gcloud auth application-default login

    En GitHub Actions las credenciales las inyecta automáticamente la action
    'google-github-actions/auth@v2' via Workload Identity Federation (WIF).
    Para ejecución local se recomienda la opción ADC (opción 3).
    """
    # Opción 1: JSON de SA embebido en variable de entorno.
    if os.getenv("GOOGLE_CREDENTIALS"):
        # Verificar que el contenido sea JSON válido antes de continuar.
        try:
            json.loads(os.environ["GOOGLE_CREDENTIALS"])
            info("Credenciales GCP: GOOGLE_CREDENTIALS (JSON en variable de entorno).")
            return
        except json.JSONDecodeError:
            error("GOOGLE_CREDENTIALS contiene JSON invalido.")
            sys.exit(1)

    # Opción 2: Ruta a archivo JSON de cuenta de servicio.
    sa_file = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if sa_file:
        if Path(sa_file).exists():
            info(f"Credenciales GCP: GOOGLE_APPLICATION_CREDENTIALS={sa_file}")
            return
        else:
            error(f"GOOGLE_APPLICATION_CREDENTIALS apunta a un archivo inexistente: {sa_file}")
            sys.exit(1)

    # Opción 3: Application Default Credentials (ADC).
    adc_path = Path.home() / ".config" / "gcloud" / "application_default_credentials.json"
    if adc_path.exists():
        info(f"Credenciales GCP: Application Default Credentials ({adc_path})")
        return

    # No se encontró ninguna forma de autenticación.
    error(
        "No se encontraron credenciales GCP. Usa una de estas opciones:\n"
        "  A) gcloud auth application-default login\n"
        "  B) export GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/sa-key.json\n"
        "  C) export GOOGLE_CREDENTIALS=$(cat /ruta/a/sa-key.json)"
    )
    sys.exit(1)


# ══════════════════════════════════════════════════════════════════════════════
# Interfaz de línea de comandos
# ══════════════════════════════════════════════════════════════════════════════

def parse_args() -> argparse.Namespace:
    """Define y parsea los argumentos del CLI."""
    parser = argparse.ArgumentParser(
        description="Pipeline de despliegue de Terraform en GCP (equivalente Python del workflow YAML).",
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

    # Localizar la raíz del repositorio y el directorio de trabajo gcp/.
    # __file__ apunta a scripts/gcp_deploy.py -> parent.parent es la raíz.
    repo_root   = Path(__file__).resolve().parent.parent
    working_dir = repo_root / "gcp"

    if not working_dir.is_dir():
        error(f"Directorio gcp/ no encontrado en {working_dir}")
        sys.exit(1)

    # Cabecera del pipeline.
    print(_color(f"\n{'=' * 60}", BOLD))
    print(_color(f"  Pipeline GCP Terraform  |  env={args.env}", BOLD))
    print(_color(f"{'=' * 60}\n", BOLD))

    # Verificar credenciales GCP antes de hacer cualquier trabajo.
    check_auth_env()

    # ── Ejecutar cada etapa en secuencia ──────────────────────────────────────
    # Cada etapa falla con sys.exit(1) si encuentra un error, deteniendo el
    # pipeline completo — igual que el comportamiento needs: del YAML.

    if not args.skip_secrets_scan:
        scan_secrets(repo_root)                              # Etapa 1

    validate(working_dir, args.env)                          # Etapa 2

    plan_file, destroy_count = plan(working_dir, args.env)   # Etapa 3

    # La puerta anti-destroy se evalúa incluso en --plan-only para dar
    # retroalimentación temprana sin necesidad de llegar al apply.
    destroy_gate(destroy_count, args.force_destroy)          # Etapa 4

    if args.plan_only:
        warn("Flag --plan-only activo — omitiendo apply.")
        sys.exit(0)

    apply(working_dir, plan_file, args.env)                  # Etapa 5

    print()
    success("Pipeline GCP finalizado exitosamente.")


if __name__ == "__main__":
    main()
