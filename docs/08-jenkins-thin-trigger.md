# 08 — Jenkins thin trigger

Jenkins is only a **button + parameters**. It must not contain AWS/GCP/Azure API code.

## What Jenkins does

```text
Parameters (customer, cloud, env, account, region, action, dry-run)
        |
        v
python -m orchestrator ...
        |
        v
(optional) ansible-playbook -i generated inventory ...
```

## What Jenkins must NOT do

- Hardcode account IDs in Groovy scripts (use parameters / registry)  
- Embed long-lived cloud access keys in the job  
- Call EC2/GCP/Azure APIs directly  
- Maintain static IP lists  

## File in this repo

[jenkins/Jenkinsfile](../jenkins/Jenkinsfile)

## How to try without Jenkins

```bash
PYTHONPATH=. python3 -m orchestrator --cloud aws --customer nike \
  --account 111111111111 --environment prod --region us-east-1 --dry-run \
  --accounts-file config/accounts.yaml.example
```

Same code path Jenkins uses.

## If Jenkins is down

Existing CloudWatch Agent metrics and alarms **continue**.  
Only **new** enrollment/reconcile jobs are delayed.

See [reliability.md](reliability.md).

## Credentials

Prefer:

- IAM role on the Jenkins agent  
- AWS SSO / OIDC  

Never commit access keys. Optional ExternalId via Jenkins credentials → env `LUCIDITY_EXTERNAL_ID`.
