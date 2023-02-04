# Replace with your config

# Use your Materialize username's email
USER="<USER>";

# Use your Materialize password
PASSWORD="<PASSWORD>";

# Set the basic authorization e.g.: "Basic am9hcXVpbk..." / Helpful link: https://www.blitter.se/utils/basic-authentication-header-generator/
AUTHORIZATION="Basic ..";

# Set the Materialize cloud IP. / Help: Use `ping 4eylxyd....us-east-1.aws.materialize.cloud` to get your environment IP.
MATERIALIZE_IP="<IP>";

# Set the queries you want to use. You can change them on runtime but it is WIP.
# E.g.: http://localhost:8080/subscribe?query=metrics&token=<token>
#   query=metrics is the name of the SQL you want to execute
#   metrics = SELECT * FROM mz_internal.mz_cluster_replica_metrics;
#
# If you want to use the `sub` field from a JWT token simply use '\$1'
# E.g.: http://localhost:8080/subscribe?query=sub&token=<token>
# sub = SELECT $1 as sub;
#
# Important: Remember to scape characters like '$1', '*', or '"'.
QUERIES="{
    sub = \"SELECT \$1 as sub\",
    metrics = \"SELECT \* FROM mz_internal.mz_cluster_replica_metrics\"
}"

# Do not touch
QUERIES=`echo ${QUERIES} | tr '\n' "\\n"`
sed -e "s/\${USER}/\"${USER}\"/" \
    -e "s/\${PASSWORD}/\"${PASSWORD}\"/" \
    -e "s/\${AUTHORIZATION}/\"${AUTHORIZATION}\"/" \
    -e "s/\${MATERIALIZE_IP}/${MATERIALIZE_IP}/" \
    -e "s/\${QUERIES}/${QUERIES}/" default-bearer.lua > bearer.lua