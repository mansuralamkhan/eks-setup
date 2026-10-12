CLUSTER ?= my-eks-cluster
REGION  ?= ap-south-1

.PHONY: up down kubeconfig pin velero-bucket test fmt

up:            ## create the cluster and AWS resources (costs money while it runs)
	terraform -chdir=01-foundation init
	terraform -chdir=01-foundation apply

down:          ## destroy everything Terraform created
	terraform -chdir=01-foundation destroy

kubeconfig:
	aws eks update-kubeconfig --name $(CLUSTER) --region $(REGION)

pin:           ## resolve PIN_LATEST chart versions in 05-gitops/apps (needs helm)
	./scripts/pin_charts.py

velero-bucket: ## write the Terraform-created bucket name into the Velero values
	./scripts/set-velero-bucket.sh

test:          ## run the local checks that CI runs (needs kyverno, promtool, kubeconform)
	terraform fmt -check -recursive 01-foundation
	./07-policy/run-tests.sh
	./scripts/test-prometheus-rules.sh

fmt:
	terraform fmt -recursive 01-foundation
