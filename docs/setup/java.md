# Java / Gradle / Maven

Current Drive sources: Temurin JDK 21, Gradle 9.7.1, and Maven 3.9.16 under `java/`.

```bash
./kit.sh install java
source /mnt/data/java-kit/env.sh
java -version
gradle --version
mvn --version
```

The toolchain is extracted rootlessly and exposed through the generated `env.sh`.

Default workspace: `/mnt/data/java-kit`.
