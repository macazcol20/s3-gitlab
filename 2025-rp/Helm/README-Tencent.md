# Reflect Project Service (STG)

### Pull secrets from GCS
```sh
gsutil -m cp -r 'gs://reflect-secrets/china/*' ./
```

## Deploy Project Server

[README-Tencent](project/envs/README-Tencent.md)

## Initial Postgresql on DB-Client instance
### Install dotnet-sdk-3.1.300
```sh
wget https://download.visualstudio.microsoft.com/download/pr/0c795076-b679-457e-8267-f9dd20a8ca28/02446ea777b6f5a5478cd3244d8ed65b/dotnet-sdk-3.1.300-linux-x64.tar.gz
mkdir -p $HOME/dotnet && tar zxf dotnet-sdk-3.1.300-linux-x64.tar.gz -C $HOME/dotnet
export DOTNET_ROOT=$HOME/dotnet
export PATH=$PATH:$HOME/dotnet
```

### Install dotnet-ef
```sh
dotnet tool install --global dotnet-ef
export PATH=$PATH:$HOME/.dotnet/tools
```

### Create the file Projects/ProjectServer/usersettings.json and put below contents into it
```sh
{
    "ConnectionStrings": {
        "ProjectServiceDatabase": "Host=<IP>;Database=ProjectService;Username=postgres;Password=<PASSWORD>"
    }
}
```

### Creating the schema
```sh
cd Projects/ProjectServer
dotnet ef database update
```
