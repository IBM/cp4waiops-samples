#!/bin/sh
set -e

if [ -z "${STORAGE_CLASS}" ]; then
    echo "Please provide a storage class using STORAGE_CLASS."
    exit 1
fi

if [ -z "${IMAGE}" ]; then
    IMAGE="icr.io/cpopen/cp4waiops/storage-benchmark@sha256:2fe040c8aa646c6e3524ce9eb48c1cf7b9cd23afbec57543212d0b3b3cfa793f"
fi

if [ -z "${SIZE}" ]; then
    SIZE="5Gi"
fi

cat << EOF | kubectl apply --validate -f -
apiVersion: v1
kind: Namespace
metadata:
  name: aiops-storage-benchmark
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: storage-benchmark
  namespace: aiops-storage-benchmark
spec:
  storageClassName: ${STORAGE_CLASS}
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${SIZE}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: storage-benchmark
  namespace: aiops-storage-benchmark
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                - amd64
      containers:
      - name: storage-benchmark
        image: ${IMAGE}
        imagePullPolicy: Always
        env:
        - name: MOUNT_DIR
          value: /data
        volumeMounts:
        - name: storage-benchmark-pv
          mountPath: /data
        resources:
          limits:
            cpu: 250m
            memory: 200Mi
          requests:
            cpu: 250m
            memory: 200Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          privileged: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
      restartPolicy: Never
      volumes:
      - name: storage-benchmark-pv
        persistentVolumeClaim:
          claimName: storage-benchmark
      securityContext:
        runAsNonRoot: true
  backoffLimit: 4
  completions: 1
  parallelism: 1
EOF
