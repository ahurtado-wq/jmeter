#!/bin/bash
set -euo pipefail

# =========================================================
# JMeter Performance Test Runner (Docker) – HARD CODED
# =========================================================

# =============== ENV VARIABLES ===========================
export TARGET_PROTOCOL="https"
export TARGET_HOST="appcrm.datacrm.la"
export TARGET_PORT="443"
export TARGET_PATH="/datacrm/cpuniminuto/index.php"
export TARGET_KEYWORD="DataCRM"
export JM_USERNAME="ahurtado"
export JM_PASSWORD="12345678"

# =============== PATHS ===================================
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
T_DIR="$BASE_DIR/tests/trivial"
R_DIR="$T_DIR/report"
JTL_FILE="$T_DIR/test-plan.jtl"
JMETER_LOG="$T_DIR/jmeter.log"

HTML_PUBLISH_DIR="/var/www/html/jmeter"
DASHBOARD_URL="https://develop.datacrm.com/jmeter"

SUMMARY_FILE="$BASE_DIR/summary.txt"

# =============== EMAIL (HARD CODED) ======================
SMTP_HOST="smtp.mailersend.net"
SMTP_PORT="587"
SMTP_USER="MS_teAat1@datacrm.com"
SMTP_PASS="MAILERSEND_PASSWORD_AQUI"

EMAIL_FROM="QA-DEVOPS-POSTMAN@datacrm.com"
EMAIL_TO="ahurtado@datacrm.com"

# =============== THRESHOLDS ==============================
P95_LIMIT=1500
ERROR_RATE_LIMIT=1.0

# =============== CLEAN OLD CONTAINER =====================
docker rm -f jmeter 2>/dev/null || true

# =============== CLEAN REPORT DIR ========================
rm -rf "$R_DIR" > /dev/null 2>&1
mkdir -p "$R_DIR"
rm -f "$JTL_FILE" "$JMETER_LOG" > /dev/null 2>&1

# =============== EXECUTE JMETER ==========================
echo "▶ Running JMeter tests..."

./run.sh -Dlog_level.jmeter=DEBUG \
  -JTARGET_HOST="$TARGET_HOST" \
  -JTARGET_PORT="$TARGET_PORT" \
  -JTARGET_PATH="$TARGET_PATH" \
  -JTARGET_KEYWORD="$TARGET_KEYWORD" \
  -n -t "$T_DIR/test-plan.jmx" \
  -l "$JTL_FILE" \
  -j "$JMETER_LOG" \
  -e -o "$R_DIR"

# =============== PUBLISH HTML ============================
echo "▶ Publishing HTML dashboard..."

sudo rm -rf "$HTML_PUBLISH_DIR"
sudo mkdir -p "$HTML_PUBLISH_DIR"
sudo cp -r "$R_DIR/"* "$HTML_PUBLISH_DIR"

echo "Dashboard available at: $DASHBOARD_URL"

# =============== ANALYZE RESULTS =========================
echo "▶ Analyzing results..."

python3 <<EOF > "$SUMMARY_FILE"
import pandas as pd

df = pd.read_csv("${JTL_FILE}")

total = len(df)
errors = len(df[~df["success"]])
error_rate = round((errors / total) * 100, 2)

avg = round(df["elapsed"].mean(), 2)
p95 = round(df["elapsed"].quantile(0.95), 2)

slow = (
    df.groupby("label")["elapsed"]
    .mean()
    .sort_values(ascending=False)
    .head(3)
)

status = "OK" if error_rate < ${ERROR_RATE_LIMIT} and p95 < ${P95_LIMIT} else "ATENCION"

print(f"STATUS={status}")
print(f"ERROR_RATE={error_rate}")
print(f"AVG={avg}")
print(f"P95={p95}")
print("SLOW_ENDPOINTS:")
print(slow.to_string())
EOF

cat "$SUMMARY_FILE"

STATUS=$(grep "STATUS=" "$SUMMARY_FILE" | cut -d'=' -f2)
ERROR_RATE=$(grep "ERROR_RATE=" "$SUMMARY_FILE" | cut -d'=' -f2)
P95=$(grep "P95=" "$SUMMARY_FILE" | cut -d'=' -f2)

# =============== SEND EMAIL (PYTHON SMTP) ================
python3 <<EOF
import smtplib
from email.mime.text import MIMEText

subject_ok = "[JMeter][develop] Performance OK"
subject_fail = "[JMeter][develop] Performance ATENCION"

subject = subject_ok if "$STATUS" == "OK" else subject_fail

body = f"""
<h2>Pruebas de performance – develop</h2>
<p><b>Estado:</b> {"✅ OK" if "$STATUS" == "OK" else "⚠️ ATENCIÓN"}</p>
<p><b>P95:</b> { "$P95" } ms</p>
<p><b>Error rate:</b> { "$ERROR_RATE" }%</p>
<p><a href="{ "$DASHBOARD_URL" }">👉 Ver dashboard completo</a></p>
<pre>{open("$SUMMARY_FILE").read()}</pre>
"""

msg = MIMEText(body, "html")
msg["Subject"] = subject
msg["From"] = "$EMAIL_FROM"
msg["To"] = "$EMAIL_TO"

server = smtplib.SMTP("$SMTP_HOST", int("$SMTP_PORT"))
server.starttls()
server.login("$SMTP_USER", "$SMTP_PASS")
server.send_message(msg)
server.quit()
EOF

if [ "$STATUS" = "OK" ]; then
  exit 0
else
  exit 1
fi
