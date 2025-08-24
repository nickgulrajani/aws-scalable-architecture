.PHONY: dry-run plan helm summary show clean

TF_DIR := terraform
TFVARS := tfvars/minimal.tfvars
PLAN   := $(TF_DIR)/tfplan.binary
PLAN_JSON := tfplan.json
HELM_RENDER := helm/rendered.yaml
SUMMARY := plan-summary.md

dry-run: plan helm summary
	@echo "✅ Dry run complete."
	@echo "• $(PLAN)"
	@echo "• $(PLAN_JSON)"
	@echo "• $(HELM_RENDER)"
	@echo "• $(SUMMARY)"

plan:
	terraform -chdir=$(TF_DIR) init -backend=false
	terraform -chdir=$(TF_DIR) fmt -recursive
	terraform -chdir=$(TF_DIR) validate
	terraform -chdir=$(TF_DIR) plan -refresh=false \
		-var-file=../$(TFVARS) \
		-out=tfplan.binary
	terraform -chdir=$(TF_DIR) show -json tfplan.binary > $(PLAN_JSON)

helm:
	helm lint helm/app
	helm template retail-app helm/app -f helm/app/values.yaml > $(HELM_RENDER)
	@head -n 40 $(HELM_RENDER) || true

summary:
	@which jq >/dev/null || (echo "jq is required (brew install jq)"; exit 1)
	@ADDS=$$(jq '[.resource_changes[]? | select(.change.actions|index("create"))] | length' $(PLAN_JSON)); \
	CHANGES=$$(jq '[.resource_changes[]? | select(.change.actions|index("update"))] | length' $(PLAN_JSON)); \
	DESTROYS=$$(jq '[.resource_changes[]? | select(.change.actions|index("delete"))] | length' $(PLAN_JSON)); \
	TOP=$$(jq -r '[.resource_changes[]? | select(.change.actions|index("create")) | .type] \
	| group_by(.) | map({type: .[0], count: length}) \
	| sort_by(-.count) | .[0:10] \
	| (["Type","Creates"] as $$h | $$h), (.[] | [.type, (.count|tostring)]) | @tsv' $(PLAN_JSON) | column -t); \
	{ \
	  echo "# Terraform Plan Summary"; \
	  echo; \
	  echo "**Adds:** $$ADDS  |  **Changes:** $$CHANGES  |  **Destroys:** $$DESTROYS"; \
	  echo; \
	  echo "## Top Created Resource Types"; \
	  if [ -n "$$TOP" ]; then echo; echo '```text'; echo "$$TOP"; echo '```'; else echo; echo "_No new resources in plan._"; fi; \
	  echo; \
	  echo "## Helm Render"; \
	  echo "Rendered manifests at $(HELM_RENDER)."; \
	} > $(SUMMARY)
	@sed -n '1,60p' $(SUMMARY)

show:
	terraform -chdir=$(TF_DIR) show $(PLAN) | sed -n '1,160p'

clean:
	rm -f $(PLAN_JSON) $(HELM_RENDER) $(SUMMARY) $(PLAN)

