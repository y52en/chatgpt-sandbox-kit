# .NET SDK

Current Drive source: `dotnet/dotnet-sdk-linux-x64.tar.gz`. The release metadata JSON is retained alongside it as reference metadata.

```bash
./kit.sh install dotnet
source /mnt/data/dotnet-kit/env.sh
dotnet --info
```

The SDK is extracted rootlessly and exposed through the generated `env.sh`.

Default workspace: `/mnt/data/dotnet-kit`.
