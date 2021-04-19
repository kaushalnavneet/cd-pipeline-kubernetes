function cluster_config() {
    # 1 - cluster name
    for iteration in {1..30}
    do
        echo "Running cluster config for cluster $1: $iteration / 30"
        ibmcloud ks cluster config --cluster $1
        if [[ $? -eq 0 ]]; then
            return 0
        else
            echo "Cluster config for $1 failed. Trying again..."
            sleep 5
        fi
    done
    return 1
}