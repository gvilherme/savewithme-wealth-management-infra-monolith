# Workflows — savewithme-wealth-management-infra-monolith

## Visão geral

```
push feature/*
    → tf-plan.yml roda
    → plan OK → PR aberto automaticamente para main + Copilot review
    → aprovação manual + "Terraform Plan" check verde obrigatório
    → merge → tf-apply.yml roda → infraestrutura provisionada na AWS
```

---

## tf-plan.yml

**Trigger:** push em `feature/**` OU pull_request para `main`

**O que faz:**
1. Autentica na AWS via OIDC (role read-only: `ROLE_ARN_PLAN`)
2. `terraform init` com bucket S3 do state (`TF_STATE_BUCKET`)
3. `terraform validate` + `terraform plan`
4. **Se push em feature/\*:** abre PR para `main` automaticamente com o plan no body; solicita review do `github-copilot[bot]`; se PR já existe, adiciona comentário com o novo plan
5. **Se PR event:** comenta o plan diretamente no PR
6. Falha o workflow se o plan falhar (bloqueia merge)

**Secrets necessários:** `ROLE_ARN_PLAN`, `AWS_REGION`, `TF_STATE_BUCKET`, `SSH_PUBLIC_KEY`

---

## tf-apply.yml

**Trigger:** push em `main` (merge do PR) OU `workflow_dispatch`

**O que faz:**
1. Autentica na AWS via OIDC (role com escrita: `ROLE_ARN`)
2. `terraform init` + `terraform apply -auto-approve`
3. Exibe outputs (incluindo `ec2_public_ip`)

**Secrets necessários:** `ROLE_ARN`, `AWS_REGION`, `TF_STATE_BUCKET`, `SSH_PUBLIC_KEY`

**Environment:** `production` — respeita required reviewers se configurado

---

## stack-control.yml

**Trigger:** label adicionada a qualquer issue

**Labels disponíveis:**

| Label | Efeito |
|-------|--------|
| `stack:destroy` | `terraform destroy` — destrói toda a infra |
| `stack:recreate` | `terraform destroy` + `terraform apply` — recria do zero |

**O que faz (stack:recreate):**
1. Destrói a infra atual
2. Recria via terraform apply
3. Comenta os outputs na issue
4. Fecha a issue

> ⚠️ Só o owner do repositório pode disparar (verificação via `github.actor`).
> O state Terraform fica no S3, então mesmo após destroy o apply sabe o que recriar.

---

## Proteção da branch main

Configurar em: Settings → Branches → Branch protection rules → `main`

- Required status checks: `Terraform Plan` (nome exato do job)
- Require pull request before merging
- Required approvals: 1
- Require branches to be up to date before merging

---

## Secrets configurados (repo-level)

| Secret | Uso |
|--------|-----|
| `ROLE_ARN` | IAM Role para apply (tf-apply + stack-control) |
| `ROLE_ARN_PLAN` | IAM Role read-only (tf-plan) |
| `AWS_REGION` | Região AWS (us-east-1) |
| `TF_STATE_BUCKET` | Nome do bucket S3 do Terraform state |
| `SSH_PUBLIC_KEY` | Chave pública injetada no EC2 |
