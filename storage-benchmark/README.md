# AIOps Storage Benchmark
The scripts provided here can be used to deploy and remove a storage benchmark utility job that measures the IOPS performance of a given storage class.

## Usage
### Deploy
1. Connect to your cluster running AIOps, so it is accessible using `kubectl` via the command line
2. Run the following command and provide the name of the storage class you want to test:
    ```sh
    STORAGE_CLASS=<AIOps Storage Class> ./storage_benchmark.sh
    ```

### Uninstall
1. Connect to your cluster running AIOps, so it is accessible using `kubectl` via the command line
2. Run the following command
    ```sh
    ./uninstall_benchmark.sh
    ```
