aws eks update-kubeconfig --region ap-south-1 --name my-eks-cluster
kubectl get nodes
kubectl get pods -A

aws eks describe-nodegroup --cluster-name my-eks-cluster --nodegroup-name my-eks-cluster-managed-ng --query "nodegroup.{status:status,scalingConfig:scalingConfig,health:health}"

aws eks describe-cluster --name my-eks-cluster --query "cluster.version"

curl -4 ifconfig.me

aws configure list
echo $AWS_PROFILE
echo $AWS_DEFAULT_REGION
aws eks list-clusters --region ap-south-1

aws configure set region ap-south-1

aws eks describe-cluster --name my-eks-cluster --query "cluster.version"
aws eks describe-nodegroup --cluster-name my-eks-cluster --nodegroup-name my-eks-cluster-managed-ng --query "nodegroup.{status:status,scalingConfig:scalingConfig,health:health}"

kubectl get pods -o wide | grep nginx | grep Running | wc -l


kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork,POD_IP:.status.podIP,NODE_IP:.status.hostIP

aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=my-eks-cluster-managed-ng" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" --output text
kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true
kubectl set env daemonset aws-node -n kube-system --list | grep PREFIX

kubectl describe node ip-10-0-4-59.ap-south-1.compute.internal | grep -A 15 "Capacity:"