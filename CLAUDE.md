# SaveWithMe — Infra (Terraform monolith)

## O que é esse repo

Repositório de **Infrastructure as Code** do SaveWithMe (app de gestão financeira pessoal — pessoas físicas no Brasil, GTechnologia). Provisiona a stack AWS que hospeda o backend monolítico e expõe o app para os usuários.

Não há código de aplicação aqui. Para back e front, ver:
- `savewithme-wealth-management-backend`
- `savewithme-wealth-management-frontend`

---

## 📚 Specs globais — contexto do produto

A documentação de produto e arquitetura do SaveWithMe vive **fora dos repos de código**, num workspace compartilhado:

```
C:\Users\rodri\OneDrive\Documentos\Claude\Projects\App de gerenciamento de capital, savewithme\specs\
```

Para tarefas de infra, raramente é necessário consultar specs de produto. Mas vale conhecer a estrutura, especialmente quando uma mudança de infra é motivada por necessidade de feature (ex: scheduler novo precisa de rodar com cron, exige IAM diferente, etc.).

| Caminho | O que tem |
|---------|-----------|
| `specs/README.md` | Visão geral do projeto + ordem de implementação |
| `specs/features/state-machines.md` | Schedulers e jobs do back (úteis quando dimensionar instâncias) |

---

## Stack de infra

| Recurso | Tech |
|---------|------|
| Compute | EC2 t4g.small (ARM Graviton) us-east-1 |
| Banco | (PostgreSQL gerenciado a definir / hoje no Docker Compose junto da app) |
| Mensageria | RabbitMQ (mesmo Docker Compose) |
| Registry | GHCR (build no GitHub Actions, EC2 só faz pull) |
| Auth AWS no CI | OIDC (sem credenciais de longa duração) |
| State do Terraform | Bucket S3 dedicado |
| Deploy | SSM `AWS-RunShellScript` — sem SSH direto, instância descoberta pela tag `Name=savewithme-ec2` |

---

## Workflows

| Workflow | Trigger | O que faz |
|----------|---------|-----------|
| `tf-plan.yml` | PR para `main` (de qualquer feature/*) | `terraform plan` e comenta no PR |
| `tf-apply.yml` | merge em `main` | `terraform apply` |
| `stack-control.yml` | issue label `stack:destroy` ou `stack:recreate` | destrói/recria a stack inteira |

---

## Convenções

- **Branch strategy:** `feature/*` → PR → `main`. CI auto-abre PR conforme padrão dos outros repos.
- **Nada de credenciais hardcoded.** Tudo via OIDC / SSM Parameter Store / Secrets Manager.
- **Mudanças destrutivas exigem aviso.** Especialmente quando afetam EC2 ou state bucket.
- **`terraform.tfvars` é git-ignored.** Use `terraform.tfvars.example` para documentar variáveis.

---

## Decisões já tomadas

- **t4g.small (ARM Graviton).** Migrado de t3.small por custo. Docker images do back usam `platforms: linux/arm64`.
- **Sem load balancer no MVP.** App exposto direto na 8080. ALB + ACM entram quando o domínio público entrar.
- **Sem Nginx no MVP.** SSL/proxy reverso pós-MVP.
- **State bucket separado por ambiente.** Hoje só prod. Staging quando precisar.
- **Deploy via SSM, não SSH.** Por segurança e simplicidade — não precisa abrir 22, não precisa rotacionar chave.

---

## Manutenção deste arquivo

Atualize sempre que:
- Recursos novos forem provisionados (RDS, ALB, CloudFront, etc.)
- A estratégia de deploy mudar
- Algum workflow novo aparecer ou mudar de comportamento
- Decisão de custo/region/tipo de instância mudar
