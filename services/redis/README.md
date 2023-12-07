

SELECT * FROM pg_authid WHERE rolname='[USER]';


export TENANT_ID=eeaa109900005eef00003ddc0000436f
export TIMELINE_ID=eeaa646e0000233c000068f90000301e

curl -v -H "Content-Type: application/json" -d "{\"new_tenant_id\": \"$TENANT_ID\"}" https://neon-pageserver-api.home.cristiano.cloud/v1/tenant/

curl -v      -X POST -H "Content-Type: application/json" -d "{\"new_timeline_id\": \"$TIMELINE_ID\", \"pg_version\": 16}" "https://neon-pageserver-api.home.cristiano.cloud/v1/tenant/$TENANT_ID/timeline/"
