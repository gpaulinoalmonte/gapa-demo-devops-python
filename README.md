---
title: Prueba Devsu
uuid: 745c6a12-07c3-11f0-821d-d75fab7be944
version: 253
created: '2025-03-23T04:48:05-04:00'
---

Documentacion: George A. Paulino A.

\

Como utilizo azure-devops en mi antigua cuenta de universidad estare colocando todo el codigo en este repo de github [https://github.com/gpaulinoalmonte/gapa-demo-devops-python](https://github.com/gpaulinoalmonte/gapa-demo-devops-python), ademas en el mismo repo en donde se encuentra el codigo estare coloando el IaC que se llama `IaC-devsu-test`.


---

\

Paso 1: Buenos dias, para este prueba realice lo siguiente, cree un dockerfile para realizar el levantamiento de la aplicacion:

\

```
FROM python:3.11.3-slim

WORKDIR /app

# Copiar solo el archivo requirements.txt para aprovechar el cache de Docker
COPY requirements.txt .

# Instalar las dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el resto del código de la aplicación
COPY . .

# Copiar el archivo .env
COPY .env .env

# Añadir permisos solo si es necesario para depuración
RUN mkdir -p /app/data && chmod -R 755 /app/data

EXPOSE 3000

# Comando para ejecutar el servidor
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
 
```


---

Paso 2: Modifique el archivo settings.py `ALLOWED_HOSTS = \['\*'\]` para permitir el acceso global desde cualquier host, ya que me estaba fallando al momento de levantar el servicio

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/3b1805fd-1080-4cb3-932e-d008c7ee4b97.png) [^1]

\


---

\

Paso 3: Stages de los pipelines:

\

### Stages:

1. **Preparar el Entorno**:

    1. Prepara el entorno de trabajo.

1. **Instalar Dependencias**:

    1. Usa la versión de Python configurada e instala las dependencias desde `requirements.txt`.

1. **Análisis de Código con Pylint**:

    1. Se instalo Pylint y para que ejecute un análisis estático del código con Pylint, marcando los resultados con colores.

1. **Ejecutar Pruebas Unitarias**:

    1. Se instalan las dependencias necesarias para ejecutar pruebas y luego ejecuta las pruebas unitarias configuradas con `python manage.py test`.

1. **Cobertura de Pruebas**:

    1. Se ejecutan las pruebas unitarias con cobertura y se genera un informe de la cobertura.

1. **Construir y Subir Imagen Docker**:

    1. Construye la imagen Docker con el nombre generado dinámicamente, la sube a Docker Hub utilizando el nombre de usuario y contraseña proporcionados como variables de entorno.

1. **Publicar Artefactos**:

    1. Publica los artefactos del build generados, asegurando que se guarden en el directorio adecuado.

\

```
trigger:
  - dev # Ajusta la rama según tu flujo de trabajo

pool:
  vmImage: 'ubuntu-latest' # O puedes usar la imagen que prefieras

variables:
  pythonVersion: '3.11.3' # Ajusta la versión de Python que estés usando
  IMAGE_NAME: 'myapp-$(Build.BuildId)' # Usa el ID de build para la imagen Docker
  IMAGE_TAG: 'latest'
  FULL_IMAGE_NAME: '$(DOCKER_USERNAME)/$(IMAGE_NAME):$(IMAGE_TAG)'

stages:
- stage: PrepareEnvironment
  displayName: 'Preparar el Entorno'
  jobs:
  - job: Prepare
    displayName: 'Preparar entorno de trabajo'
    steps:
    - script: echo "Preparando el entorno..."
      displayName: 'Preparar entorno'

- stage: InstallDependencies
  displayName: 'Instalar Dependencias'
  jobs:
  - job: Install
    displayName: 'Instalar Dependencias'
    steps:
    - task: UsePythonVersion@0
      inputs:
        versionSpec: '$(pythonVersion)'  # Usa la versión de Python
        addToPath: true

    - script: |
        echo "Instalando dependencias de Python..."
        pip install -r requirements.txt
      displayName: 'Instalar dependencias'

- stage: CodeAnalysis
  displayName: 'Análisis de Código con Pylint'
  jobs:
  - job: PylintAnalysis
    displayName: 'Análisis estático con Pylint'
    steps:
    - script: pip install pylint
      displayName: 'Instalar Pylint'

    - script: |
        echo "Ejecutando análisis de código con Pylint..."
        export PYTHONPATH=$(pwd)
        pylint api demo --output-format=colorized --score=n || true  # Análisis con color
      displayName: 'Ejecutar análisis Pylint'
      continueOnError: true

- stage: UnitTests
  displayName: 'Ejecutar Pruebas Unitarias'
  jobs:
  - job: RunTests
    displayName: 'Ejecutar pruebas unitarias'
    steps:
    - script: pip install -r requirements.txt
      displayName: 'Instalar dependencias para pruebas'

    - script: |
        echo "Configurando DJANGO_SETTINGS_MODULE..."
        export DJANGO_SETTINGS_MODULE=demo.settings
        echo "Ejecutando pruebas..."
        python manage.py test  # Ejecución de pruebas unitarias
      displayName: 'Ejecutar pruebas'

- stage: TestCoverage
  displayName: 'Cobertura de Pruebas'
  jobs:
  - job: Coverage
    displayName: 'Cobertura de pruebas'
    steps:
    - script: |
        echo "Ejecutando cobertura de pruebas..."
        pip install coverage
        coverage run manage.py test  # Ejecución de cobertura
        coverage report  # Informe de cobertura
      displayName: 'Ejecutar cobertura de pruebas'

- stage: BuildAndPublishDockerImage
  displayName: 'Construir y Subir Imagen Docker'
  jobs:
  - job: BuildAndPublish
    displayName: 'Construir y Subir Imagen Docker'
    steps:
    - script: |
        echo "Construyendo la imagen Docker con el nombre $(FULL_IMAGE_NAME)..."
        docker build -t $(FULL_IMAGE_NAME) .  # Construcción de Docker
        echo "Subiendo la imagen Docker a Docker Hub..."
        echo $(DOCKER_PASSWORD) | docker login -u $(DOCKER_USERNAME) --password-stdin
        echo "Pushing image $(FULL_IMAGE_NAME)..."  # Subida de imagen
        docker push $(FULL_IMAGE_NAME)
        echo "La imagen Docker se construyó y subió correctamente con el nombre $(FULL_IMAGE_NAME)"
      displayName: 'Construir y Subir Imagen Docker'

- stage: PublishArtifacts
  displayName: 'Publicar Artefactos'
  jobs:
  - job: Publish
    displayName: 'Publicar artefactos del build'
    steps:
    - task: PublishBuildArtifacts@1
      displayName: 'Publicar artefactos'
      condition: succeededOrFailed()
      inputs:
        pathToPublish: '$(Build.ArtifactStagingDirectory)'  # Publicación de artefactos
        artifactName: drop

```

\


---

Paso 4: se agregaron las variables de docker directamente en el pipeline.

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/3a672e35-bb9a-4a9d-9048-22060535992d.png) [^2]

\


---

\

Paso 5: Capturas de pantalla de la ejecucion del pipeline.

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/405ce925-c465-478f-bdbf-b8e3811062fb.png) [^3]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/542a55f3-5116-431e-9ba1-8594f8c13d8e.png) [^4]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/ef8970ba-5247-4f8c-a043-9c475feb647b.png) [^5]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/aaa6ae2f-7731-4157-88ee-f27fa10c4718.png) [^6]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/9cc9be17-c572-4ef2-abf1-deac27af8bd5.png) [^7]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/6b81fd17-e85d-4437-a513-a5fa03a7279e.png) [^8]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/0faa07a6-19e7-42f4-9cde-97a62cf4b689.png) [^9]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/80409a81-39ce-4b5b-a6f9-a1623ce6b91b.png) [^10]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/af9e8744-eb9a-4439-be83-9e5ab6ba18b4.png) [^11]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/0faa07a6-19e7-42f4-9cde-97a62cf4b689.png) [^12]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/fcb2e245-aeaa-4730-bb13-128ab98ba8ec.png) [^13]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/b920e4c7-0bb5-46c5-8295-b8e045f0ca04.png) [^14]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/b3912c5f-7213-4990-aaaa-045f18c06b28.png) [^15]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/5096e706-939f-4472-90a6-c046ea4e6198.png) [^16]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/25e55a86-a295-4d99-a2dd-0db09fb4d6b8.png) [^17]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/6e0f6257-4bf2-4218-bb06-d1f7f94c4cdb.png) [^18]

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/80409a81-39ce-4b5b-a6f9-a1623ce6b91b.png) [^19]

\

Paso 6: publicacion del contenedor en dockerhub:

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/bea60242-2a1d-4d65-9f56-5bea62f621b5.png) [^20]

\


---

\

Paso 7: Para el despliegue utilice openshift debido a que es mas facil de utilizar que minikube, tambien utilice argocd para el iac y kubeseal para el encriptamiento de los secrets, ahora mostrare los pasos utilizados para desplegar openshift.

\

Comando utilizado para desplegar un nodo de 50 gb, esto lo utlice asi debido a que el disco se me acababa y necesitaba espacio.

```c
crc start --disk-size 50  
```

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/21ef500b-3e9e-4505-9dd3-6092d3c5efdb.png) [^21]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/b4307095-1033-45d6-af52-4e5fe30a06e9.png) [^22]

\

Para la instalacion de argocd utilice el mismo repositorio de argocd [argoproj/argo-cd: Declarative Continuous Deployment for Kubernetes](https://github.com/argoproj/argo-cd/releases/tag/v2.14.7), ya que este cuenta con los comando necesarios para desplegarlo.

 

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/b754535e-bce0-4836-96b1-d6dd4f831c22.png) [^23]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/e50168a0-4ad1-428f-a35b-c477ad344b87.png) [^24]

\

Conecte mi repo de azure-devops a argocd.

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/ff516f91-14ad-4159-9b64-33c974840793.png) [^25]

\

Aqui les muestro los componentes desplegados por argocd.

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/7c498701-5794-490f-b3f3-fc6a972a256a.png) [^26]

\

Esta es la estructura de mi iac, lo colocare en el comprimido que les enviare.

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/7566ecf1-ce00-47a2-a25f-e591c4a412fc.png) [^27]

\

Toda la sincronizacion de mi IAC es automatica, cada vez que hago un push a la rama main, argocd revisa los cambios y lo actualiza en openshift.

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/7aeeb906-5079-4619-ab96-203284499d83.png) [^28]

\

Aqui les muestro la instalacion de kubeseal, lo realice usando directamente la documentacion. [Release sealed-secrets-v0.28.0 · bitnami-labs/sealed-secrets](https://github.com/bitnami-labs/sealed-secrets/releases/tag/v0.28.0) 

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/a8a341bc-902d-4f6b-9736-8a72117cee0a.png) [^29]

\

Un ejemplo de como encripte los secrets, lo realice de esta manera por el tiempo, pero se puede encriptar en archivos aparte `.env` .

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/8e6c989e-bd23-4dc7-b8e9-ae2c4c08cc0a.png) [^30]

\

Los nombres del secret son autogenerados, siempre cambia cuando se actualiza una variable.

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/ee4ea89f-8dc1-40ae-8b27-7ea9318d3b66.png) [^31]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/4d7d88a2-a89d-4dd0-92b3-0d426c781788.png) [^32]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/151da5ea-2637-417f-a052-041f5188a682.png) [^33]

\

Aqui les muestro una captura de un pod funcionando.

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/27490d1d-ff0b-4334-84c2-a72ad07e2bd6.png) [^34]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/ae754054-a18e-48dd-8eb2-0bdfc29e5895.png) [^35]

\

Prueba de request

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/8c79c626-83c3-4903-b3a9-9836d4579814.png) [^36]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/2a701d16-0efb-46ab-ad1f-6d0e7dfe5dd8.png) [^37]

\

![](https://images.amplenote.com/745c6a12-07c3-11f0-821d-d75fab7be944/6810475c-29f5-45b7-baeb-e5840c156c8d.png) [^38]

\

Configuracion de los yaml para openshift:

\

```
 apiVersion: apps/v1
kind: Deployment
metadata:
  name: devsu-demo-devops-python
  namespace: devsu-demo
spec:
  selector:
    matchLabels:
      app: devsu-demo-devops-python
  template:
    metadata:
      labels:
        app: devsu-demo-devops-python
    spec:
      containers:
        - name: devsu-demo-devops-python
          image: gpaulinoalmonte/myapp-101
          imagePullPolicy: Always
          envForm:
            - secretRef:
                name: secret-devsu-demo-devops-python
          resources: {}
          ports:
            - containerPort: 8000
      serviceAccountName: devsu-demo-sa
      serviceAccount: devsu-demo-sa
---
apiVersion: v1
kind: Service
metadata:
  name: devsu-demo-devops-python
  namespace: devsu-demo
spec:
  selector:
    app: devsu-demo-devops-python
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 8000
```

\

```
 apiVersion: route.openshift.io/v1
kind: Route
metadata:
  namespace: devsu-demo
  labels:
    app: devsu-demo-devops-python
  name: devsu-demo-devops-python
spec:
  host: devsu-demo-devops-python.apps-crc.testing
  port:
    targetPort: 8000
  to:
    kind: Service
    name: devsu-demo-devops-python
    weight: 100
```

\

```
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
namespace: devsu-demo

resources:
    - sa/account.yml
    - sa/devsu-demo-sa.yml
    - route/devsu-demo-devops-python.yaml
    - tools

secretGenerator:
    - name: secret-devsu-demo-devops-python
      literals:
          - PORT=8000
          - DATABASE_NAME=/app/data/dev.sqlite
          - DATABASE_USER=user
          - DATABASE_PASSWORD=password
          - NODE_ENV=production
 
```

[^1]: devsu-demo - x settings.py - R x \] Pipelines - Rur X Q kubeseal - Sea X () Release sealed X Docker Hub x 3 Extensions
    X\|
    C
    https://dev.azure.com/georgexdxd5/devsu-demo/_git/devsu-demo-devops-python?path=/demo/settings.py
    School...
    Azure Devops georgexdxd5 / devsu-demo / Repos / Files / @ devsu-demo-devops-python
    Q Search
    GA
    D devsu-demo
    devsu-demo-devops-pyth...
    & dev v
    / demo / settings.py
    Overview
    .ci-devops
    settings.py
    Edit
    api
    Contents History
    Compare Blame
    Boards
    demo
    import environ
    8 Repos
    2 from pathlib import Path
    .env
    # Build paths in
    oject like this: BASE_DIR / ' subdir' .
    Files
    .gitignore
    BASE_DIR = Path(_file_).resolve() .parent.parent
    6
    Commits
    er
    Dockerfile
    env = environ. Env ()
    env . read_env (BASE_DIR / ' .env' )
    19 Pushes
    PY manage.py
    16 # Quick-start development settings - unsuitable for production
    11 # See https://docs. djangoproject
    ct . com/en/4.2/howto/deployment/checklist/
    89 Branches
    MI README.md
    12
    # SECURITY WARNING: keep the secret key used in production secret!
    14 SECRET_KEY = env('DJANGO_SECRET_KEY' )
    Tags
    requirements.txt
    15
    16 # SECURITY WARNING: don't run with debug turned on in production!
    83 Pull requests
    17
    DEBUG = True
    ALLOWED_HOSTS = \['\*' \]
    Advanced Security
    21
    Pipelines
    22 # Application definition
    23
    4 DJANGO_APPS = \[
    Test Plans
    25
    'django. contribadmin' ,
    django. contribauth',
    'django. contribcontenttypes' ,
    Artifacts
    28
    'django. contribessions' ,
    29
    django. contribumessages' ,
    30
    'django . contribscaticfiles' ,
    31
    32
    THIRD_PARTY_APPS = \[
    "rest_framework' ,
    7 LOCAL_APPS = \[
    38
    'ap1' ,
    INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS
    MIDDLEWARE = \[
    'django. middleware. security. SecurityMiddleware' ,
    45
    'django. contribessions.middleware. SessionMiddleware' ,
    46
    "django. middleware . common. CommonMiddleware' ,
    47
    48
    "django. middleware. carf . (srfViewMiddleware' ,
    'django. contribauth.middleware.AuthenticationMiddleware' ,
    django. contribu messages. middleware. MessageMiddleware' ,
    django. middleware . clickjacking.XFrameOptionsMiddleware' ,
    \]
    ROOT_URLCONF = ' demo . urls'
    RANAMARERA
    TEMPLATES = \[
    'BACKEND' : 'django. template. backends . django. DjangoTemplates' ,
    "DIRS' : \[\],
    "APP_DIRS' : True,
    60
    ' OPTIONS' : {
    62
    "context_processors' : \[
    'django. template. context_processors. debug',
    'django. template. context_processors. request',
    64
    "django. contribauth. context_processors. auth',
    65
    django.contribmessages.context_processors.messages' ,
    8 9
    Project settings
    4:52:25 AM
    N
    XI
    3/23/2025

[^2]: devsu-dem X
    J devsu-dem X
    Pipelines - \| X Q kubeseal - x () Release sea X Docker Hul X 3 Extensions X
    New tab
    X
    +
    X
    G
    https://dev.azure.com/georgexdxd5/devsu-demo/_apps/hub/ms.vss-build-web.ci-designer-hub?pipelineld=6&branch=dev
    School
    Azure Devops georgexdxd5 / devsu-demo / Pipelines
    Variables
    X
    D
    devsu-demo
    +
    < devsu-demo-devops-python
    Q Search variables
    +
    Overview
    dev v
    devsu-demo-devops-python / .ci-devops/azure-pipelin
    Boards
    fx
    DOCKER_PASSWORD
    Repos
    fx
    DOCKER_USERNAME
    = gpaulinoa
    Pipelines
    be Pipelines
    Environments
    Releases
    Library
    Task groups
    Deployment groups
    Test Plans
    Artifacts

[^3]: devsu-dem x \] Pipelines -
    x J Pipelines - \| X Q kubeseal - x () Release sea X Docker Hul X 3 Extensions X New tab X
    G
    https://dev.azure.com/georgexdxd5/devsu-demo/_build
    School
    ...
    Azure Devops georgexdxd5
    devsu-demo / Pipelines
    Q Search
    GA
    D devsu-demo
    Pipelines
    New pipeline
    Overview
    Recent All Runs
    Filter pipelines
    Boards
    Recently run pipelines
    Repos
    Pipeline
    Last run
    Pipelines
    #20250323.5 - Updated settings.py
    45m ago
    V
    devsu-demo-devops-python
    2m 54s
    by Pipelines
    Individual Cl for GA) & dev
    & Environments
    #20250316.3 - Added pipeline.yml
    Mar 16
    X
    prueba
    8 Manually triggered for @4) & main
    0 355
    Releases
    Library
    Task groups
    "" Deployment groups
    Test Plans
    Artifacts
    Project settings
    4:57:32 AM
    3/23/2025

[^4]: devsu-dem x J Pipelines -
    x JPipelines - X Q kubeseal - x () Release sea X Docker Hut X 3 Extensions X New tab
    X
    C
    https://dev.azure.com/georgexdxd5/devsu-demo/_build?definitionld =6
    53
    (School
    . ..
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python
    Search
    GA
    D devsu-demo
    < devsu-demo-devops-python
    Edit
    Run pipeline
    Overview
    Runs Branches Analytics
    Boards
    Description
    Stages
    Repos
    #20250323.5 - Updated settings.py
    8 45m ago
    2m 54s
    Pipelines
    Individual Cl for GA) & dev 9 c380d6b5
    #20250323.4 - Updated settings.py
    V-V-V-V -O-D-D
    68 47m ago
    bur Pipelines
    O
    Individual Cl for @4) 89 dev 9 690be73f
    @ 1m 51s
    & Environments
    #20250323.3 - Updated Dockerfile
    (8 53m ago
    Releases
    Individual Cl for @4 89 dev ? ab020d13
    0 4m 1s
    In Library
    #20250323.2 - Updated Dockerfile
    O-0-0-0-0-0-0
    8 1h ago
    Individual Cl for GA) 89 dev 9 65ec5654
    0 3m 1s
    Task groups
    #20250323.1 - Updated azure-pipeline.yml
    ( 2h ago
    "+ Deployment groups
    0-0-0-0-0-0-
    Individual Cl for @4) & dev 9 6c3dle58
    3m 52s
    Test Plans
    #20250322.5 - Updated azure-pipeline.yml
    O-0-0-0-0-0-0
    Yesterday
    Individual Cl for GA) 8 dev 9 4cfbb9a5
    0 3m 4s
    Artifacts
    #20250322.4 . Updated azure-pipeline.yml
    Yesterday
    X
    O-V-V-X -0-0-0
    Individual Cl for @4) & dev 9 81593944
    0 1m 31s
    #20250322.3 - Updated azure-pipeline.yml
    to Yesterday
    Individual Cl for @4) 8 dev 9 581eee83
    3m 37s
    #20250322.2 - Updated azure-pipeline.yml
    Yesterday
    8 Manually triggered for @) & dev 9 42968427
    0 <1s
    #20250322.1 - Updated azure-pipeline.yml
    x
    -X-0-0-0-0-0
    Yesterday
    Individual Cl for @) 8 dev 9 42968427
    0 58s
    #20250316.36 - Updated azure-pipeline.yml
    O-0-0-0-0-0-0
    Mar 16
    Individual Cl for GA) 89 dev ? af7e65e2
    0 3m 29s
    #20250316.35 . Updated azure-pipeline.yml
    -V-V-V-V-O-
    Mar 16
    Individual Cl for @) 8 dev 9 3db10c6d
    2m 57s
    #20250316.34 . Updated azure-pipeline.yml
    Mar 16
    Individual Cl for @4) 8 dev 9 c5056f08
    3m 36s
    #20250316.33 - Updated azure-pipeline.yml
    O-0-0-0-0-0-
    Mar 16
    Individual Cl for @4) 8 dev ? f5b173df
    0 3m 11s
    #20250316.32 - Updated azure-pipeline.yml
    O-V-X-0
    Mar 16
    x
    Individual Cl for @) 8 dev 9 41bf3be6
    55s
    #20250316.31 - Updated azure-pipeline.yml
    O-0-0-0-0-0-
    Mar 16
    Individual Cl for GA) 8 dev 9 0958f496
    3m 11s
    #20250316.30 - Updated azure-pipeline.yml
    Mar 16
    Project settings
    <<
    Individual Cl for @4) & dev 9 90a9d2cc
    0 5m 46s
    4:57:40 AM
    XI
    U N V 4 -
    3/23/2025

[^5]: devsu-dem x J Pipelines -
    x JPipelines - X Q kubeseal - x () Release sea X
    Docker Hut X 3Extensions X New tab
    X
    ...
    C
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld =101&view=logs&j=eca2d878-4e52-5641-d828-e3...
    53
    (School
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    Jobs in run #202...
    Initialize job
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: Initialize job
    Boards
    Preparar el Entorno
    Agent name: "Hosted Agent'
    Agent machine name: 'fv-az428-375.
    Preparar entorno...
    Repos
    Current agent version: '4.253.0'
    Operating System
    Initialize job
    <1s
    9 > Runner Image
    Pipelines
    14 > Runner Image Provisioner
    Checkout devs...
    1s
    16
    Current image version: '20250316.1.0'
    bur Pipelines
    17
    Agent running as: 'vsts'
    Preparar ent...
    <1s
    18
    Prepare build directory.
    & Environments
    19
    Set build variables.
    Post-job: Che...
    <1s
    20
    Download all required tasks.
    Releases
    Downloading task: CmdLine (2.250.1)
    Finalize Job
    1s
    checking job knob settings.
    In Library
    Knob: DockerActionRetries = true Source: $(VSTSAGENT_DOCKER_ACTION_RETRIES)
    Instalar Dependencias
    Knob: AgentToolsDirectory = /opt/hostedtoolcache Source: ${AGENT_TOOLSDIRECTORY}
    Task groups
    seGitLongPaths = true Source: $(USE_GIT_LONG_PATHS)
    Instalar Depend...
    23s
    : AgentPerflog =
    (home/vsts/perflog Source: ${VSTS_AGENT_PERFLOG}
    "+ Deployment groups
    ion = true Source: $(ENABLE_ISSUE_SOURCE_VALIDATION)
    Initialize job
    1s
    heArtifactLargeChunkSize = true Source: $(AGENT_ENABLE_PIPELINEARTIFACT_LA
    Test Plans
    ProcessTreeKillAttempt = true Source: $(VSTSAGENT_CONTINUE_AFTER_CANCEL_
    Checkout devs...
    1s
    ts = false Source: $(AZP_75787_ENABLE_NEW_LOGIC)
    uments = false Source: $(AZP_75787_ENABLE_NEW_LOGIC_LOG)
    Artifacts
    UsePythonVe...
    14s
    emetry = true Source: $(AZP_75787_ENABLE_COLLECT)
    erTelemetry = True Source: $(DistributedTask. Agent. USENEWNODEHANDLERTELEMETRY
    Instalar depen..
    15s
    ic = true Source: $(AZP_75787_ENABLE_NEW_PH_LOGIC)
    orDebugOutput = true Source: $(AZP_ENABLE_RESOURCE_MONITOR_DEBUG_OUTPUT)
    Post-job: Che...
    <1s
    ceutilizationWarnings = true Source: $(AZP_ENABLE_RESOURCE_UTILIZATION_WARNINGS)
    true Source: $(AZP_AGENT_IGNORE_VSTSTASKLIB)
    Finalize Job
    <1s
    nAgentDies = true Source: $(FAIL_JOB_WHEN_AGENT_DIES)
    ecation = true Source: $(AZP_AGENT_CHECK_FOR_TASK_DEPRECATION)
    Analisis de Codigo con Pylint
    unner IsDeprecated246 = False Source: $(DistributedTask. Agent. CheckIfTaskNode
    Node20ToStartContainer = True Source: $(DistributedTask.Agent. UseNode20ToStartContainer)
    Y
    serAgent = true Source: $(AZP_AGENT_LOG_TASKNAME_IN_USERAGENT)
    Analisis estatico...
    11s
    UseFetchFilter InCheckoutTask = true Source: $(AGENT_USE_FETCH_FILTER_IN_CHECKOUT_TASK)
    Initialize job
    : Rosetta2Warning = true Source: $(ROSETTA2_WARNING)
    1S
    AddForceCre
    entialsToGitCheckout = True Source: $(DistributedTask. Agent. AddForceCredentials
    Knob: UseSparseCheckoutInCheckoutTask = true Source: $(AGENT_USE_SPARSE_CHECKOUT_IN_CHECKOUT_TASK)
    Checkout devs...
    2c
    inished checking job knob settings.
    48
    Instalar Pylint
    Start tracking orphan processes.
    Finishing: Initialize job
    Ejecutar analisi...
    15
    Post-job: Che...
    Finalize Job
    1
    Ejecutar Pruebas Unitarias
    V
    Ejecutar prueba...
    15s
    Initialize job
    3 1s
    Checkout devs...
    Instalar depe...
    11s
    Project settings
    4:58:24 AM
    XI
    A S_
    3/23/2025

[^6]: devsu-dem x J Pipelines -
    I X Pipelines - X Q kubeseal -
    x ) Release sea X
    Docker Hut X Extensions X New tab x
    C
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=eca2d878-4e52-5641-d828-e3...
    School..'
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    - Jobs in run #202...
    Checkout devsu-demo-devops-python@d...
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: Checkout devsu-
    devops-python@dev to s
    Boards
    Preparar el Entorno
    Task
    : Get sources
    V
    Repos
    Preparar entorno...
    Description : Get sources from a repository. Supports Git, TfsVC, and SVN repositories.
    5
    Version
    : 1.0.0
    Initialize job
    319
    6
    Author
    : Microsoft
    Pipelines
    7
    He Ip
    : \[More Information \] (https://go.microsoft.com/fwlink/?LinkId=798199)
    Checkout devs...
    1s
    bid Pipelines
    9
    Syncing repository: devsu-demo-devops-python (Git)
    Preparar ent...
    <1s
    git version
    Environments
    11
    git version 2.48.1
    Post-job: Che.
    <1s
    12
    git Ifs version
    Releases
    13
    git-1fs/3.6.1 (GitHub; linux amd64; go 1.23.3)
    Finalize Job
    <1s
    14
    git init "/home/vsts/work/1/s"
    I Library
    15
    hint: Using '
    as the name for the initial branch. This default branch name
    Instalar Dependencias
    16
    hint: is subject to change. To configure the initial branch name to use in all
    Task groups
    17
    hint: of your new repositories, which will suppress this warning, call:
    Instalar Depend...
    23s
    18
    hint :
    Deployment groups
    19
    hint:
    git config --global init. defaultBranch <name>
    Initialize job
    is
    20
    hint:
    Test Plans
    21
    hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
    Checkout devs..
    15
    22
    hint: 'development' . The just-created branch can be renamed via this command:
    Artifacts
    23
    hint
    UsePythonVe...
    14s
    24
    hint: git branch -m <name>
    25
    Initialized empty Git repository in /home/vsts/work/1/s/ .git/
    Instalar depen...
    15s
    26
    git remote add origin https://georgexdxd5@dev. azure.com/georgexdxd5/devsu-demo/_git/devsu-demo-devo
    27
    git sparse-checkout disable
    Post-job: Che...
    <1s
    28
    git config gc.auto 0
    29
    git config core . longpaths true
    Finalize Job
    <1s
    30
    git config --get-all http.https://georgexdxd5@dev.azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-
    31
    git config --get-all http. extraheader
    Analisis de Codigo con Pylint
    32 git config --get-regexp .\*extraheader
    33
    git config --get-all http.proxy
    Analisis estatico..
    git config http. version HTTP/1.1
    11s
    35 git --config-env=http. extraheader=env_var_http. extraheader fetch --force --tags --prune --prune-tag
    Initialize job
    remote: Azure Repos
    K<1s
    37
    remote:
    38
    Checkout devs...
    remote: Found 26 objects to send. (14 ms)
    2s
    39
    from https://dev. azure.com/georgexdxd5/devsu-demo/_git/devsu-demo-devops=python
    40
    \* \[new ref\]
    <380d6b50ae492e6c152342428d7752e5a687ef8 -> origin/c380d6b50ae492e6c152342428d
    Instalar Pylint
    65
    41
    git --config-env=http. extraheader=env_var_http. extraheader fetch --force --tags --prune --prune-tag
    42
    Ejecutar analisi...
    remote: Azure Repos
    1s
    43
    remote:
    Post-job: Che...
    44
    remote: Found 0 objects to send. (0 ms)
    <1s
    45
    from https://dev.azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-devops-python
    46
    <380d6b50ae492e6c152342428d7752e5a687ef8 -> FETCH_HEAD
    Finalize Job
    <1s
    47
    it checkout --progress --force refs/remote
    ae492e6c152342428d7752e5a687ef8
    48
    Note: switching to 'refs/remotes/origin/c380d6b50ae492e6c152342428d7752e5a687ef8' .
    Ejecutar Pruebas Unitarias
    49
    50
    You are in 'detached HEAD' state. You can look around, make experimental
    Ejecutar prueba...
    15s
    51
    ges and commit them, and you can discard any commits you make in this
    52
    state without impacting any branches by switching back to a branch.
    Initialize job
    <1s
    53
    54
    If you want to create a new branch to retain commits you create, you may
    v
    Checkout devs...
    1s
    55
    do so (now or later) by using -c with the switch command. Example:
    56
    Project settings
    Instalar depe...
    11
    57
    git switch -c <new-branch-name>
    4:58:32 AM
    XI
    A >
    o
    N V 4 - - 74)
    /23/2025

[^7]: devsu-dem x Pipelines - \| X \]Pipelines - X Q kubeseal - x () Release sea X
    Docker Hut X 3 Extensions x \| New tab x \| +
    School...
    G
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=eca2d878-4e52-5641-d828-e3...
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    - Jobs in run #202...
    Preparar entorno
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: Preparar entorno
    Boards
    Preparar el Entorno
    Task
    : Command line
    Preparar entorno..
    3s
    Description : Run a command line script using Bash on Linux and macOS and cmd. exe on Windows
    Repos
    Version
    : 2.250.1
    Initialize job
    Author
    : Microsoft Corporation
    Pipelines
    Help
    : https://docs.microsoft. com/azure/devops/pipelines/tasks/utility/command-line
    Checkout devs...
    bid Pipelines
    Generating script
    Preparar ent...
    <1s
    10
    Script contents:
    Environments
    11
    echo "Preparando el entorno. . ."
    Post-job: Che..
    <1s
    23== Starting Command Output =
    Releases
    /usr/bin/bash --noprofile --norc /home/vsts/work/_temp/962bdc85-2a91-43a2-a3da-3bd2ed248887 . sh
    Finalize Job
    1s
    Preparando el entorno. ..
    In Library
    15
    Instalar Dependencias
    16
    Finishing: Preparar entorno
    Task groups
    Instalar Depend...
    23s
    " Deployment groups
    Initialize job
    19
    Test Plans
    Checkout devs..
    Artifacts
    UsePythonVe...
    14s
    Instalar depen...
    5s
    Post-job: Che...
    <1s
    Finalize Job
    <1s
    Analisis de Codigo con Pylint
    Analisis estatico...
    11s
    Initialize job
    1s
    Checkout devs...
    2s
    Instalar Pylint
    65
    Ejecutar analisi...
    15
    Post-job: Che...
    1s
    Finalize Job
    <1s
    Ejecutar Pruebas Unitarias
    Ejecutar prueba...
    15s
    Initialize job
    1s
    Checkout devs...
    1s
    Instalar depe..
    11
    Project settings
    4:58:40 AM
    \~ G U N V 4 - - 71)
    3/23/2025
    A

[^8]: Pipelines - \| X Q kubeseal - x () Release sea X Docker Hul X Extensions X New tab
    X
    devsu-dem x \] Pipelines - \| X
    (School
    . ..
    C
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results? buildld=101&view=logs&j=eca2d878-4e52-5641-d828-e3...
    Q Search
    GA
    Azure Devops georgexdxd5 /
    devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    D devsu-demo
    Post-job: Checkout devsu-demo-devops-python@...
    Q
    View raw log
    Jobs in run #202...
    devsu-demo-devops-python
    Overview
    Starting: Checkout devsu-de
    onedev to s
    Preparar el Entorno
    Boards
    Task
    Get sources
    Preparar entorno...
    13
    Description : Get sources from a repository. Supports Git, TFsVC, and SVN repositories.
    Repos
    Version
    : 1.0.0
    Initialize job
    <15
    Author
    : Microsoft
    : \[More Information\] (https://go.microsoft. com/fwlink/?LinkId=798199)
    Pipelines
    Help
    Checkout devs...
    is
    Cleaning any cached credential from repository: devsu-demo-devops-python (Git)
    bu Pipelines
    Preparar ent...
    <1s
    Finishing: Checkout devsu-demo-devops-python@dev to s
    & Environments
    Post-job: Che...
    <1s
    Releases
    Finalize Job
    <1s
    In Library
    Instalar Dependencias
    Task groups
    Instalar Depend...
    23s
    "" Deployment groups
    Initialize job
    is
    Test Plans
    Checkout devs..
    1s
    Artifacts
    UsePythonVe...
    14s
    Instalar depen..
    5s
    Post-job: Che...
    1s
    Finalize Job
    <1s
    Analisis de Codigo con Pylint
    V
    Analisis estatico...
    11s
    Initialize job
    15
    Checkout devs...
    Instalar Pylint
    Ejecutar analisi...
    Post-job: Che...
    1s
    Finalize Job
    Ejecutar Pruebas Unitarias
    Ejecutar prueba...
    15s
    Initialize job
    31s
    Checkout devs...
    Instalar depe...
    11s
    Project settings
    4:58:51 AM
    U N V 4 - - 71
    3/23/2025
    A > HO

[^9]: devsu-dem x J Pipelines -
    I X Pipelines - X Q kubeseal -
    x ) Release sea X
    Docker Hut X Extensions X New tab x
    C
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=70d87c7b-ae91-5344-efc0-96f..
    School..'
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    - Jobs in run #202...
    Checkout devsu-demo-devops-python@d...
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: Checkout devsu-
    Boards
    Preparar el Entorno
    devops-python@dev to s
    Task
    : Get sources
    V
    Repos
    Preparar entorno...
    Bs
    Description : Get sources from a repository. Supports Git, TFsVC, and SVN repositories.
    5
    Version
    : 1.0.0
    Initialize job
    6
    Author
    : Microsoft
    Pipelines
    7
    Help
    : \[More Information \] (https://go.microsoft.com/fwlink/?LinkId=798199)
    Checkout devs...
    1s
    bid Pipelines
    9
    Syncing repository: devsu-demo-devops-python (Git)
    Preparar ent...
    <1s
    git version
    Environments
    11
    git version 2.48.1
    Post-job: Che..
    <1s
    12
    git Ifs version
    Releases
    13
    git-1fs/3.6.1 (GitHub; linux amd64; go 1.23.3)
    Finalize Job
    <1s
    14
    git init "/home/vsts/work/1/s"
    I Library
    15
    hint: Using '
    as the name for the initial branch. This default branch name
    Instalar Dependencias
    16
    hint: is subject to change. To configure the initial branch name to use in all
    Task groups
    17
    hint: of your new repositories, which will suppress this warning, call:
    Instalar Depend...
    23s
    18
    hint :
    Deployment groups
    19
    hint:
    git config --global init. defaultBranch <name>
    Initialize job
    is
    20
    hint:
    Test Plans
    21
    hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
    Checkout devs...
    1s
    22
    hint: 'development' . The just-created branch can be renamed via this command:
    Artifacts
    23
    hint:
    UsePythonVe...
    14s
    24
    hint: git branch -m <name>
    25
    Initialized empty Git repository in /home/vsts/work/1/s/ .git/
    Instalar depen...
    15s
    26
    git remote add origin https://georgexdxd5@dev. azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-devo
    27
    git sparse-checkout disable
    Post-job: Che...
    <1s
    28
    git config gc.auto 0
    29
    git config core . longpaths true
    Finalize Job
    <1s
    git config --get-all http.https://georgexdxd5@dev.azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-
    31
    git config --get-all http. extraheader
    Analisis de Codigo con Pylint
    32 git config --get-regexp .\*extraheader
    33
    git config --get-all http.proxy
    Analisis estatico..
    git config http.version HTTP/1.1
    11s
    35 git --config-env=http.extraheader=env_var_http. extraheader fetch --force --tags --prune --prune-tag
    Initialize job
    remote: Azure Repos
    K<1s
    37
    remote:
    38
    Checkout devs...
    remote: Found 26 objects to send. (0 ms)
    2s
    39
    from https ://dev. azure.com/georgexdxd5/devsu-demo/_git/devsu-demo-devops=python
    40
    Instalar Pylint
    \* \[new ref\]
    c380d6b50ae492e6c152342428d7752e5a687ef8 -> origin/c380d6b50ae492e6c152342428d
    65
    41
    git --config-env=http. extraheader=env_var_http. extraheader fetch --force --tags --prune --prune-tag
    42
    Ejecutar analisi...
    remote: Azure Repos
    1s
    43
    remote:
    Post-job: Che...
    44
    remote: Found 0 objects to send. (0 ms)
    <1s
    45
    from https://dev.azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-devops-python
    46
    c380d6b50ae492e6c152342428d7752e5a687ef8 -> FETCH_HEAD
    Finalize Job
    <1s
    47
    it checkout --progress --force refs/remote
    ae492e6c152342428d7752e5a687ef8
    48
    Note: switching to 'refs/remotes/origin/c380d6b50ae492e6c152342428d7752e5a687ef8' .
    Ejecutar Pruebas Unitarias
    49
    50
    You are in 'detached HEAD' state. You can look around, make experimental
    Ejecutar prueba...
    15s
    51
    ges and commit them, and you can discard any commits you make in this
    52
    state without impacting any branches by switching back to a branch.
    Initialize job
    <1s
    53
    54
    If you want to create a new branch to retain commits you create, you may
    v
    Checkout devs...
    1s
    55
    do so (now or later) by using -c with the switch command. Example:
    56
    Project settings
    Instalar depe...
    11
    57
    git switch -c <new-branch-name>
    o
    N V 4 - - 74
    1:58:59 AM
    XI
    A >
    /23/2025

[^10]: devsu-dem x \] Pipelines -
    I X J Pipelines -
    X Q kubeseal - x () Release sea X Docker Hul X 3 Extensions X New tab x
    ...
    G
    eorgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=70d87c7b-ae91-5344-efc0-96f...
    School
    https://dev.azure.com/georgexax
    GA
    Azure Devops georgexdxd5
    devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    D devsu-demo
    Jobs in run #202...
    UsePythonVersion
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: UsePythonVersion
    Boards
    Preparar el Entorno
    Task
    : Use Python version
    Preparar entorno...
    Description : Use the specified version of Python from the tool cache, optionally adding it to the
    Repos
    Version
    : 0.248.1
    Initialize job
    31s
    Author
    : Microsoft Corporation
    Pipelines
    Help
    : https://docs.microsoft.com/azure/devops/pipelines/tasks/tool/use-python-version
    Checkout devs...
    Pipelines
    ch versions
    Preparar ent...
    <1s
    10
    ## \[warning \]You
    . Otherwise you m
    & Environments
    11
    Downloading: https://github. com/actions/python-versions/releases/download/3. 11.3-11059198104/python-3
    Post-job: Che...
    <1s
    12
    Extracting archive
    Releases
    13
    /usr/bin/tar xC /home/vsts/work/_temp/7dlace83-7670-49f6-alaa-681bc8b5c8fc -f /home/vsts/work/_temp/F
    Finalize Job
    <1s
    14
    In Library
    15
    /usr/bin/bash . /setup. sh
    Instalar Dependencias
    16
    Check if Python hostedtoolcache folder exist...
    Task groups
    17
    Create Python 3.11.3 folder
    Instalar Depend...
    23s
    18
    Copy Python binaries to hostedtoolcache folder
    Deployment groups
    19
    Create additional symlinks (Required for the UsePythonVersion Azure Pipelines task and the setup-pyth
    Initialize job
    15
    20
    Upgrading pip. . .
    Test Plans
    21
    Looking in links: /tmp/tmph65ou7qd
    Checkout devs...
    1s
    22
    Requirement already satisfied: setuptools in /opt/hostedtoolcache/Python/3.11.3/x64/lib/python3.11/si
    23
    Requirement already satisfied: pip in /opt/hostedtoolcache/Python/3.11.3/x64/lib/python3.11/site-pack
    Artifacts
    UsePythonVe...
    14s
    24
    Collecting pip
    25
    Downloading pip-25.0.1-py3-none-any . wh1 (1.8 MB)
    Instalar depen...
    55
    26
    - 1.8/1.8 MB 7.6 MB/s eta 0:00:00
    27
    Installing collected packages: pip
    Post-job: Che...
    <1s
    Attempting uninstall: pip
    Found existing installation: pip 22.3.1
    Finalize Job
    <1s
    Uninstalling pip-22.3.1:
    Successfully uninstalled pip-22.3.1
    Analisis de Codigo con Pylint
    Successfully installed pip-25.0.1
    Create complete file
    34
    V
    Analisis estatico...
    11s
    35
    Found tool in cache: Python 3.11.3 x64
    36
    Prepending PATH environment variable with directory: /opt/hostedtoolcache/Python/3.11.3/x64
    Initialize job
    <1s
    37
    Prepending PATH environment variable with directory: /opt/hostedtoolcache/Python/3.11.3/x64/bin
    38
    Finishing: UsePythonVersion
    Checkout devs...
    Instalar Pylint
    CC
    Ejecutar analisi...
    Post-job: Che...
    <1s
    Finalize Job
    <1
    Ejecutar Pruebas Unitarias
    V
    Ejecutar prueba...
    15s
    Initialize job
    <1s
    Checkout devs...
    1s
    Instalar depe...
    11s
    Project settings
    <<
    4:59:06 AM
    P
    3/23/2025

[^11]: devsu-dem x J Pipelines - \| X
    JPipelines - X
    Q kubeseal - x () Release sea
    Docker Hul X 3 Extensions X New tab x +
    <
    G
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=70d87c7b-ae91-5344-efc0-96f..
    School..'
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    - Jobs in run #202...
    Instalar dependencias
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: Instalar dependencias
    Boards
    Preparar el Entorno
    Task
    : Command line
    V
    Preparar entorno...
    Repos
    Description : Run a command line script using Bash on Linux and macOS and cmd. exe on Windows
    5
    Version
    : 2.250.1
    Initialize job
    Author
    : Microsoft Corporation
    Pipelines
    Help
    : https://docs.microsoft. com/azure/devops/pipelines/tasks/utility/command-line
    Checkout devs...
    bid Pipelines
    Generating script.
    Preparar ent...
    <1s
    ezzzz292= Starting Command Output =
    & Environments
    /usr/bin/bash --noprofile --norc /home/vsts/work/_temp/ca25age7-b89c-40cf-863e-8bfcc0a69c14. sh
    Post-job: Che..
    <1s
    Instalando dependencias de Python. . .
    Releases
    Collecting django==4.2 (from -r requirements. txt (line 1))
    Finalize Job
    <1s
    Downloading Django-4.2-py3-none-any . wh1 . metadata (4.1 kB)
    I Library
    15
    Collecting django-
    n==0.10.0 (from -r requirements. txt (line 2))
    Instalar Dependencias
    Downloading django_environ-0.10.0-py2.py3-none-any . wh1. metadata (13 kB)
    Task groups
    ollecting djangores
    ework==3.14.0 (from -r requirements. txt (line 3))
    Instalar Depend...
    23s
    loading djangorestframe
    ork-3.14.0-py3-none-any .wh1.metadata (10 KB)
    " Deployment groups
    ollecting pytest==7.2.2 (from -r requirements. txt (line 4))
    Initialize job
    Downloading pytest-7.2.2-py3-none-any . wh1.metadata (7.8 kB)
    Test Plans
    Collecting asgiref<4, >=3.6.0 (from django==4.2->-r requirements. txt (line 1))
    Checkout devs..
    is
    ng asgiref-3.8.1-py3-none-any . wh1. metadata (9.3 kB)
    Artifacts
    Collecting sqlparse>=0.3.1 (from django==4.2->-r requirements. txt (line 1))
    UsePythonVe...
    14
    Downloading sqlparse-0.5.3-py3-non
    -any .whi. metadata (3.9 kB)
    Collecting pytz (from djangorestfra
    ework=-3.14.0->-r requirements. txt (line 3))
    Instalar depen...
    Downloading pytz-2025.1-py2. py3-none-any . wh1. metadata (22 kB)
    Collecting attrs>=19.2.0 (from pytest==7.2.2->-r requirements. txt (line 4))
    Post-job: Che...
    <1s
    Downloading attrs-25.3.0-py3-none-any . wh1.metadata (10 kB)
    collecting iniconfig (from pytest==7.2.2->-r requirements. txt (line 4))
    Finalize Job
    <1s
    Downloading iniconfig-2.1.0-py3-none-any . wh1. metadata (2.7 kB)
    Collecting packaging (from pytest==7.2.2->-r requirements. txt (line 4))
    Analisis de Codigo con Pylint
    Downloading packaging-24.2-py3-none-any . wh1. metadata (3.2 kB)
    collecting pluggy<2.0, >=0.12 (from pytest==7.2.2->-r requirements. txt (line 4))
    V
    Analisis estatico..
    Downloading pluggy-1.5.0-py3-none-any . whi.metadata (4.8 kB)
    11s
    Downloading Django-4.2-py3-none-any . wh1 (8.0 MB)
    - 8.0/8.0 MB 111.8 MB/s eta 0:00:00
    Initialize job
    <1s
    Downloading django_environ-0.10.0-py2.py3-none-any . whl (19 kB)
    38
    Downloading djangorestframework-3.14.0-py3-none-any .whl (1.1 MB)
    Checkout devs...
    2s
    39
    - 1.1/1.1 MB 81.1 MB/s eta 0:00:00
    40
    Instalar Pylint
    Downloading pytest-7.2.2-py3-none-any . wh1 (317 kB)
    41
    Downloading asgiref-3.8.1-py3-none-any .wh1 (23 kB)
    42
    -any . wh1 (63 kB)
    Ejecutar analisi...
    Downloading attrs-25.3.0-py3-non
    43
    Downloading pluggy-1.5.0-py3-none-any . wh1 (20 kB)
    Downloading sqlparse-0.5.3-py3-none-any .whl (44 kB)
    Post-job: Che...
    <1s
    45
    Downloading iniconfig-2.1.0-py3-none-any . wh1 (6.0 KB)
    46
    Finalize Job
    Downloading packaging-24.2-py3-none-any .wh1 (65 kB)
    <1s
    47
    Downloading pytz-2025.1-py2. py3-none-any . wh1 (507 kB)
    48
    Installing collected packages: pytz, sqlparse, pluggy, packaging, iniconfig, django-environ, attrs,
    Ejecutar Pruebas Unitarias
    49
    Successfully installed asgiref-3.8.1 attrs-25.3.0 django-4.2 django-environ-0.10.0 djangorestframewo
    50
    Ejecutar prueba...
    15s
    Finishing: Instalar dependencias
    Initialize job
    Checkout devs...
    15
    Project settings
    Instalar depe...
    11
    4:59:13 AM
    N
    A
    o
    A
    U N V 4 - - 71
    3/23/2025

[^12]: devsu-dem x J Pipelines -
    I X Pipelines - X Q kubeseal -
    x ) Release sea X
    Docker Hut X Extensions X New tab x
    C
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=70d87c7b-ae91-5344-efc0-96f..
    School..'
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    - Jobs in run #202...
    Checkout devsu-demo-devops-python@d...
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: Checkout devsu-
    Boards
    Preparar el Entorno
    devops-python@dev to s
    Task
    : Get sources
    V
    Repos
    Preparar entorno...
    Bs
    Description : Get sources from a repository. Supports Git, TFsVC, and SVN repositories.
    5
    Version
    : 1.0.0
    Initialize job
    6
    Author
    : Microsoft
    Pipelines
    7
    Help
    : \[More Information \] (https://go.microsoft.com/fwlink/?LinkId=798199)
    Checkout devs...
    1s
    bid Pipelines
    9
    Syncing repository: devsu-demo-devops-python (Git)
    Preparar ent...
    <1s
    git version
    Environments
    11
    git version 2.48.1
    Post-job: Che..
    <1s
    12
    git Ifs version
    Releases
    13
    git-1fs/3.6.1 (GitHub; linux amd64; go 1.23.3)
    Finalize Job
    <1s
    14
    git init "/home/vsts/work/1/s"
    I Library
    15
    hint: Using '
    as the name for the initial branch. This default branch name
    Instalar Dependencias
    16
    hint: is subject to change. To configure the initial branch name to use in all
    Task groups
    17
    hint: of your new repositories, which will suppress this warning, call:
    Instalar Depend...
    23s
    18
    hint :
    Deployment groups
    19
    hint:
    git config --global init. defaultBranch <name>
    Initialize job
    is
    20
    hint:
    Test Plans
    21
    hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
    Checkout devs...
    1s
    22
    hint: 'development' . The just-created branch can be renamed via this command:
    Artifacts
    23
    hint:
    UsePythonVe...
    14s
    24
    hint: git branch -m <name>
    25
    Initialized empty Git repository in /home/vsts/work/1/s/ .git/
    Instalar depen...
    15s
    26
    git remote add origin https://georgexdxd5@dev. azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-devo
    27
    git sparse-checkout disable
    Post-job: Che...
    <1s
    28
    git config gc.auto 0
    29
    git config core . longpaths true
    Finalize Job
    <1s
    git config --get-all http.https://georgexdxd5@dev.azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-
    31
    git config --get-all http. extraheader
    Analisis de Codigo con Pylint
    32 git config --get-regexp .\*extraheader
    33
    git config --get-all http.proxy
    Analisis estatico..
    git config http.version HTTP/1.1
    11s
    35 git --config-env=http.extraheader=env_var_http. extraheader fetch --force --tags --prune --prune-tag
    Initialize job
    remote: Azure Repos
    K<1s
    37
    remote:
    38
    Checkout devs...
    remote: Found 26 objects to send. (0 ms)
    2s
    39
    from https ://dev. azure.com/georgexdxd5/devsu-demo/_git/devsu-demo-devops=python
    40
    Instalar Pylint
    \* \[new ref\]
    c380d6b50ae492e6c152342428d7752e5a687ef8 -> origin/c380d6b50ae492e6c152342428d
    65
    41
    git --config-env=http. extraheader=env_var_http. extraheader fetch --force --tags --prune --prune-tag
    42
    Ejecutar analisi...
    remote: Azure Repos
    1s
    43
    remote:
    Post-job: Che...
    44
    remote: Found 0 objects to send. (0 ms)
    <1s
    45
    from https://dev.azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-devops-python
    46
    c380d6b50ae492e6c152342428d7752e5a687ef8 -> FETCH_HEAD
    Finalize Job
    <1s
    47
    it checkout --progress --force refs/remote
    ae492e6c152342428d7752e5a687ef8
    48
    Note: switching to 'refs/remotes/origin/c380d6b50ae492e6c152342428d7752e5a687ef8' .
    Ejecutar Pruebas Unitarias
    49
    50
    You are in 'detached HEAD' state. You can look around, make experimental
    Ejecutar prueba...
    15s
    51
    ges and commit them, and you can discard any commits you make in this
    52
    state without impacting any branches by switching back to a branch.
    Initialize job
    <1s
    53
    54
    If you want to create a new branch to retain commits you create, you may
    v
    Checkout devs...
    1s
    55
    do so (now or later) by using -c with the switch command. Example:
    56
    Project settings
    Instalar depe...
    11
    57
    git switch -c <new-branch-name>
    o
    N V 4 - - 74
    1:58:59 AM
    XI
    A >
    /23/2025

[^13]: devsu-dem x
    J Pipelines
    x J Pipelines -
    X Q kubeseal - x () Release sea X
    Docker Hul X { Extensions X New tab
    X
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld =101&view=logs&j=4420ee27-ac12-553f-8d4b-82..
    (School
    . ..
    C
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    - Jobs in run #202...
    Checkout devsu-demo-devops-python@d...
    Q
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: Checkout devsu-de
    Boards
    Preparar el Entorno
    Task
    : Get sources
    Preparar entorno...
    3s
    Repos
    Description : Get sources from a repository. Supports Git, TFsVC, and SVN repositories.
    Version
    : 1.0.0
    Initialize job
    K1s
    Author
    : Microsoft
    Pipelines
    Help
    : \[More Information \] (https://go.microsoft.com/fwlink/?LinkId=798199)
    Checkout devs...
    15
    bur Pipelines
    Syncing repository: devsu-demo-devops-python (Git)
    Preparar ent...
    <1s
    10
    git version
    & Environments
    git version 2.48.1
    Post-job: Che...
    <1s
    git Ifs version
    Releases
    git-Ifs/3.6.1 (GitHub; linux amd64; go 1.23.3)
    Finalize Job
    <1s
    git init "/home/vsts/work/1/s"
    In Library
    hint: Using 'master' as the name for the initial branch. This default branch name
    Instalar Dependencias
    hint: is subject to change. To configure the initial branch name to use in all
    Task groups
    17
    hint: of your new repositories, which will suppress this warning, call:
    Instalar Depend...
    23s
    18
    hint :
    Deployment groups
    19
    hint:
    git config --global init. defaultBranch <name>
    Initialize job
    1s
    20
    hint:
    Test Plans
    21
    hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
    Checkout devs..
    1s
    22
    hint: 'development' . The just-created branch can be renamed via this command:
    Artifacts
    23
    hint:
    UsePythonVe...
    1As
    24
    hint:
    git branch -m <name>
    25
    Initialized empty Git repository in /home/vsts/work/1/s/.git/
    Instalar depen...
    5s
    26
    git remote add origin https://georgexdxd5@dev. azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-devo
    git sparse-checkout disable
    Post-job: Che...
    <1s
    git config gc. auto 0
    29
    git config core . longpaths true
    Finalize Job
    <1s
    30
    git config --get-all http.https://georgexdxd5@dev.azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-
    git config
    -get-all http. extraheader
    Analisis de Codigo con Pylint
    git config --get-regexp . \*extraheader
    git config --get-all http.proxy
    34
    git config http.version HTTP/1.1
    V
    Analisis estatico...
    11s
    35
    git --config-env=http. extraheader=env_var_http. extraheader fetch --force --tags --prune --prune-tag:
    36
    remote: Azure Repos
    Initialize job
    21s
    37
    remote:
    38
    remote: Found 26 objects to send. (12 ms)
    Checkout devs...
    2s
    39
    From https://dev.azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-devops-python
    40
    c380d6b50ae492e6c152342428d7752e5a687ef8 -> origin/c380d6b50ae492e6c152342428d
    Instalar Pylint
    \* \[new ref\]
    41
    git --config-env=http. extraheader=env_var_http. extraheader fetch --force --tags --prune --prune-tag
    42
    remote: Azure Repos
    Ejecutar analisi...
    15
    43
    remote:
    44
    remote: Found 0 objects to send. (0 ms)
    Post-job: Che...
    1s
    45
    From https://dev. azure. com/georgexdxd5/devsu-demo/_git/devsu-demo-devops-python
    46
    c380d6b50ae492e6c152342428d7752e5a687ef8 -> FETCH_HEAD
    Finalize Job
    \* branch
    47
    it checkout --progress --force refs/remotes/origin/c380d6b50ae492e6c152342428d7752e5a687ef8
    48
    Note: switching to 'refs/remotes/origin/c380d6b50ae492e6c152342428d7752e5a687ef8' .
    Ejecutar Pruebas Unitarias
    50
    You are in 'detached HEAD' state. You can look around, make experimental
    Ejecutar prueba...
    15s
    changes and commit them, and you can discard any commits you make in this
    state without impacting any branches by switching back to a branch.
    Initialize job
    <1s
    If you want to create a new branch to retain commits you create, you may
    Checkout devs...
    do so (now or later) by using -c with the switch command. Example:
    Instalar depe...
    11s
    Project settings
    git switch -c <new-branch-name>
    4:59:21 AM
    N
    XJ
    A >_
    Op
    U N V 4 - - 71
    3/23/2025

[^14]: devsu-dem x \] Pipelines - \| X \] Pipelines - X
    Q kubeseal -
    < Release sea X
    Docker Hul X 3 Extensions X New tab x +
    G
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=4420ee27-ac12-553f-8d4b-82..
    School
    ...
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    < Jobs in run #202...
    Ejecutar analisis Pylint
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: Ejecutar analisis Pylint
    B
    Boards
    Preparar el Entorno
    WN P
    Task
    : Command line
    Preparar entorno...
    3s
    Repos
    Description : Run a command line script using Bash on Linux and macOS and cmd. exe on Windows
    Version
    : 2.250.1
    Initialize job
    41s
    6
    Author
    : Microsoft Corporation
    Pipelines
    7
    Help
    : https://docs.microsoft. com/azure/devops/pipelines/tasks/utility/command-line
    Checkout devs...
    1s
    Pipelines
    Generating script.
    Preparar ent...
    <1s
    zazz= Starting Command Output
    & Environments
    11
    /usr/bin/bash --noprofile --norc /home/vsts/work/_temp/fa9d8d3c-3d3e-4bic-9244-4e026e154453. sh
    Post-job: Che...
    <1s
    12
    Ejecutando analisis de codigo con Pylint. ..
    Releases
    13
    Finalize Job
    <1s
    14
    api/serializers . py:6:20: C0303: Trailing whitespace (trailing-whitespace)
    I Library
    15
    's.py:7:0: C0304: Final newline missing (missing-final-newline)
    Instalar Dependencias
    16
    /serializers . py:1:0: C0114: Missing module docstring (missing-module-docstring)
    Task groups
    17
    's.py:1:0: E0401: Unable to import 'rest_framework' (import-error)
    Instalar Depend...
    23s
    18
    by:4:0: co115: Missing class docstring (missing-class-docstring)
    Deployment groups
    19
    api/serializers . py:5:4: C0115: Missing class docstring (missing-class-docstring)
    Initialize job
    is
    20
    api/serializers . py:5:4: R0903: Too few public methods (0/2) (too-few-public-methods)
    Test Plans
    21
    api/serializers . py:4:0: R0903: Too few public methods (0/2) (too-few-public-methods)
    Checkout devs...
    Is
    22
    lodule api. models
    Artifacts
    23
    api/models . py:8:0: C0304: Final newline missing (missing-final-newline)
    UsePythonVe...
    14s
    24
    els .py:1:0: C0114: Missing module docstring (missing-module-docstring)
    25
    /models . py:1:0: E0401: Unable to import 'django.db' (import-error)
    Instalar depen...
    5s
    26
    api/models . py:3:0: C0115: Missing class docstring (missing-class-docstring)
    27
    api/models . py:3:0: R0903: Too few public methods (1/2) (too-few-public-methods)
    Post-job: Che...
    <1s
    28
    \*#\*\* Module api.urls
    29
    api/urls.py:8:0: C0304: Final newline missing (missing-final-newline)
    Finalize Job
    <1s
    30
    api/urls.py:1:0: C0114: Missing module docstring (missing-module-docstring)
    31
    api/urls.py:1:0: W0401: Wildcard import views (wildcard-import)
    Analisis de Codigo con Pylint
    32
    api/urls.py:2:0: E0401: Unable to import 'django.urls' (import-error)
    33
    api/urls . py:3:0: E0401: Unable to i
    'rest_framework' (import-error)
    v Analisis estatico...
    34
    api/urls.py:2:0: c0411: third party import "django.urls.path" should be placed before local import
    11s
    35
    api/urls.py:3:0: C0411: third party import "rest_framework. routers" should be placed before local is
    Initialize job
    36
    api/urls.py: 2:0: W0611: Unused path imported from django.urls (unused-import)
    37
    api/urls.py:1:0: W0614: Unused import(s) viewsets, status, Response, UserSerializer
    Checkout devs...
    38
    \* Module api. views
    2s
    39
    api/views . py :28:0: C0304: Final newline missing (missing-final-newline)
    Instalar Pylint
    40
    views . py :1:0: C0114: Missing module docstring (missing-module-docstring)
    6s
    41
    api/views . py :1:0: E0401: Unable to import 'rest_framework' (import-error)
    Ejecutar analisi...
    42
    views . py :2:0: E0401: Ur
    ork. response' (import-error)
    1s
    43
    api/views . py :6:0: C0115: Missing class docstring (missing-class-docstring)
    Post-job: Che...
    <1s
    44
    news . py : 10:4: C0116: Missing function or method docstring (missing-function-docstring)
    45
    api/views . py : 10:19: W0613: Unused argument 'request' (unused-argument)
    Finalize Job
    46
    api/views . py : 14:4: C0116: Missing function or method docstring (missing-function-docstring)
    <1s
    47
    api/views . py : 14:23: W0613: Unused argument 'request' (unused-argument)
    48
    api/views . py : 14:32: W0613: Unused argument 'pk' (unused-argument)
    Ejecutar Pruebas Unitarias
    49
    api/views . py : 18:4: C0116: Missing function or method docstring (missing-function-docstring)
    50
    api/views . py :1:0: W0611: Unused status imported from rest_framework (unused-import)
    Ejecutar prueba...
    15s
    51
    \* Module api. apps
    52
    api/apps .py:1:0: C0114: Missing module docstring (missing-module-docstring)
    Initialize job
    <1s
    53
    api/apps . py :1:0: E0401: Unable to import 'django-apps' (import-error)
    54
    api/apps . py:4:0: C0115: Missing class docstring (missing-class-docstring)
    V
    Checkout devs...
    1s
    55
    api/apps . py:4:0: R0903: Too few public methods (0/2) (too-few-public-methods)
    56
    \*#$\*#\*$2\*$\*\*\* Module api . admin
    Project settings
    Instalar depe...
    19
    57
    api/admin . py :4:0: C0304: Final newline missing (missing-final-newline)
    4:59:34 AM
    N
    XI
    A
    3/23/2025

[^15]: devsu-dem x Pipelines - X
    Pipelines - \| X Q kubeseal - X
    X ) Release sea
    Docker Hul X 3 Extensions X New tab
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=c169cc2b-51ff-5600-4fa5-85cf...
    School..'
    G
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    Jobs in run #20250323.5
    Instalar dependencias para pruebas
    View raw log
    Overview
    Instalar Pylint
    6s
    Starting: Instalar de
    Boards
    Ejecutar analisi...
    1s
    Task
    : Command line
    Repos
    Post-job: Che...
    <1s
    Description : Run a command line script using Bash on Linux and macOS and cmd. exe on Windows
    5
    Version
    : 2.250.1
    Finalize Job
    <1s
    6
    author
    : Microsoft Corporation
    Pipelines
    7
    Help
    : https://docs.microsoft.com/azure/devops/pipelines/tasks/utility/command-line
    Ejecutar Pruebas Unitarias
    Pipelines
    9
    Generating script.
    Ejecutar prueba.
    Script contents:
    15s
    _ Environments
    11
    ip install -r requirements . txt
    Initialize job
    === Starting Command Output =
    <1s
    12
    Releases
    13
    /usr/bin/bash --noprofile -
    rc /home/vsts/work/_temp/af35f834-7ae9-4bb6-984e-9681486dcded. sh
    Checkout devs...
    14
    Defaulting to user installation because normal site-packages is not writeable
    1s
    I Library
    15
    Collecting django==4.2
    Instalar depe...
    Downloading Django-4.2-py3-none-any . whil (8.0 MB)
    11s
    16
    Task groups
    17
    - 8.0/8.0 MB 16.3 MB/s eta 0:00:00
    Ejecutar pruebas
    18
    Collecting django-environ==0.10.0
    Deployment groups
    1s
    19
    Downloading django_environ-0.10.0-py2. py3-none-any . wh1 (19 kB)
    Post-job: Che...
    20
    Collecting djangorestframework==3.14.0
    1s
    Test Plans
    21
    Downloading djangorestframework-3.14.0-py3-none-any -wh1 (1.1 MB)
    41s
    22
    - 1.1/1.1 MB 28.1 MB/s eta 0:00:00
    Finalize Job
    23
    Collecting pytest==7-2.2
    Artifacts
    24
    Downloading pytest-7-2.2-py3-none-any . wh1 (317 kB)
    Cobertura de Pruebas
    25
    - 317.2/317.2 KB 57.4 MB/s eta 0:00:00
    26
    Collecting asgiref<4,>=3.6.0
    Cobertura de pr...
    10s
    Downloading asgiref-3.8.1-py3-none-any . whl (23 kB)
    28
    Collecting sqlparse>=0.3.1
    Initialize job
    <1s
    29
    Downloading sqlparse-0.5.3-py3-non
    -any .wh1 (44 kB)
    30
    - 44.4/44.4 KB 11.9 MB/s eta 0:00:00
    Checkout devs...
    1s
    31
    Requirement already satisfied: pytz in /usr/lib/python3/dist-package
    ( from djangorestframework==3.1
    32
    Requirement already satisfied: attrs>=19.2.0 in /usr/lib/python3/dist-packages (from pytest==7.2.2->
    Ejecutar cober..
    7s
    33
    satisfied: packaging in /usr/lib/python3/dist-packages (from pytest==7.2.2->-r
    34
    Requirement already satisfied: tomli>=1.0.0 in /usr/local/lib/python3. 10/dist-packages (from pytest=-
    Post-job: Che...
    <1s
    35
    Collecting iniconfig
    Downloading iniconfig-2.1.0-py3-none-any.whl (6.0 kB)
    Finalize Job
    <1s
    37
    ollecting pluggy<2.0, >=0.12
    38
    Downloading pluggy-1.5.0-py3-none-any .whi (20 kB)
    Construir y Subir Imagen Docker
    39
    Collecting exceptiongroup>=1.0.0rc8
    40
    exceptiongroup-1.2.2-py3-non
    y. wh1 (16 kB)
    V V
    Construir y Subi..
    22s
    41
    Collecting typing-extensions>=4
    42
    Downloading typing_extensions-4.12.2-py3-none-any .whl (37 kB)
    Initialize job
    <1s
    43
    Installing collected packages: typing-extensions, sqlparse, pluggy, iniconfig, exceptiongroup, django
    Successfully installed asgiref-3.8.1 django-4.2 django-environ-0.10.0 djangorestframework-3.14.0 exce
    Checkout devs...
    1s
    45
    46
    Finishing: Instalar dependencias para pruebas
    Construir y S...
    19s
    Post-job: Che...
    <1s
    Finalize Job
    <1s
    Publicar Artefactos
    Publicar artefacto...
    3s
    Project settings
    Initialize job
    <1s
    4:59:43 AM
    N
    A >
    O
    3/23/2025

[^16]: devsu-dem x Pipelines - \| X \]Pipelines - X Q kubeseal -
    x ) Release sea X
    Docker Hut X 3 Extensions X New tab x
    School...
    G
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=c169cc2b-51ff-5600-4fa5-85cf...
    Q Search
    GA
    Azure Devops georgexdxd5 / devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    D devsu-demo
    < Jobs in run #20250323.5
    Ejecutar pruebas
    View raw log
    V
    Post-job: Che...
    <1s
    Overview
    Finalize Job
    <1s
    1
    Starting: Ejecutar pruebas
    Boards
    W N
    Ejecutar Pruebas Unitarias
    Task
    : Command line
    Description : Run a command line script using Bash on Linux and macOS and cmd. exe on Windows
    89
    Repos
    Ejecutar prueba...
    Version
    : 2.250.1
    15s
    6
    Author
    : Microsoft Corporation
    Pipelines
    Help
    : https://docs.microsoft. com/azure/devops/pipelines/tasks/utility/command-line
    Initialize job
    K<1s
    bid Pipelines
    nerating script.
    Checkout devs...
    1s
    he
    === Starting Command Output
    Environments
    11
    /usr/bin/bash --noprofile --norc /home/vsts/work/_temp/96be4296-0460-4818-8a77-1dflee38a193. sh
    Instalar depe...
    11s
    12
    Configurando DJANGO_SETTINGS_MODULE. . .
    Releases
    13
    Ejecutar pruebas
    jecutando pruebas. . .
    1s
    14
    Found 3 test(s) .
    I Library
    15
    Creating test database for alias 'default' ...
    Post-job: Che...
    <1s
    16
    System check identified no issues (0 silenced) .
    Task groups
    Finalize Job
    17
    <1s
    18
    Deployment groups
    19
    Ran 3 tests in 0.015s
    Cobertura de Pruebas
    20
    TOK
    Test Plans
    21
    V
    Cobertura de pr...
    10s
    22
    Destroying test database for alias 'default' ...
    23
    Artifacts
    Initialize job
    <1s
    24
    Finishing: Ejecutar pruebas
    Checkout devs...
    1s
    Ejecutar cober...
    7s
    Post-job: Che...
    <1s
    Finalize Job
    <1s
    Construir y Subir Imagen Docker
    Construir y Subi...
    22
    Initialize job
    <1s
    Checkout devs...
    1s
    Construir y S...
    19s
    Post-job: Che...
    <1s
    Finalize Job
    <1s
    Publicar Artefactos
    Publicar artefacto...
    3s
    Initialize job
    <1s
    Checkout devs...
    1s
    Publicar artef...
    <19
    Project settings
    4:59:56 AM
    U N V 4 - - 7
    3/23/2025
    XI
    A >

[^17]: devsu-dem x
    J Pipelines
    x J Pipelines -
    X Q kubeseal - x () Release sea X
    Docker Hul X { Extensions X New tab
    X
    (School
    ...
    C
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld =101&view=logs&j=47c97f21-d047-567d-0cfb-9f1...
    Q Search
    GA
    Azure Devops georgexdxd5 /
    devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    D devsu-demo
    Jobs in run #20250323.5
    Ejecutar cobertura de pruebas
    View raw log
    Post-job: Che...
    <1s
    Overview
    Finalize Job
    <1s
    Starting: Ejecutar cobertura de pruebas
    Boards
    Ejecutar Pruebas Unitarias
    Task
    : Command line
    Description : Run a command line script using Bash on Linux and macOS and cmd. exe on Windows
    Repos
    Ejecutar prueba...
    Version
    : 2.250.1
    15s
    Author
    : Microsoft Corporation
    Pipelines
    Help
    : https://docs.microsoft. com/azure/devops/pipelines/tasks/utility/command-line
    Initialize job
    <1s
    bur Pipelines
    Checkout devs...
    Generating script.
    1s
    = Starting Command Output =
    & Environments
    Instalar depe...
    usr/bin/bash --noprofile --norc /home/vsts/work/_temp/ca2db740-d9c3-434c-ac45-54f36e003b3e. sh
    11s
    Ejecutando cobertura de pruebas. ..
    Releases
    Ejecutar pruebas
    Defaulting to user installation because normal site-packages is not writeable
    1s
    Collecting coverage
    In Library
    Downloading coverage-7.7.1-cp310-cp310-manylinux_2_5_x86_64. manylinux1_x86_64.manylinux_2_17_x86_6
    Post-job: Che...
    <1s
    239.6/239.6 KB 4.3 MB/s eta 0:00:00
    Task groups
    Finalize Job
    <1s
    Installing collected packages: coverage
    Successfully installed coverage-7.7.1
    Deployment groups
    Traceback (most recent call last):
    Cobertura de Pruebas
    File "/home/vsts/work/1/s/manage.py", line 11, in main
    Test Plans
    from django. core. management import execute_from_command_line
    Cobertura de pr...
    10s
    ModuleNotFoundError: No module named 'django'
    Artifacts
    Initialize job
    <1s
    The above exception was the direct cause of the following exception:
    Checkout devs...
    1s
    Traceback (most recent call last) :
    File "/home/vsts/work/1/s/manage. py", line 22, in <module>
    Ejecutar cober...
    7s
    main()
    File "/home/vsts/work/1/s/manage.py", line 13, in main
    Post-job: Che...
    <1s
    raise ImportError(
    ImportError: Couldn't import Django. Are you sure it's installed and available on your PYTHONPATH em
    Finalize Job
    <1s
    Name
    Stmts Miss Cover
    Construir y Subir Imagen Docker
    /usr/lib/python3/dist-packages/apport/_init_.py
    ackages/apport/fileutils. py
    V
    Construir y Subi..
    22s
    port/hookutils. py
    613
    537
    s/apport/packaging. py
    89
    Initialize job
    ackages/apport/packaging_impl. py
    996
    915
    31s
    ackages/apport/report.py
    Checkout devs...
    /python3/dist-packages/apport_python_hook. py
    117
    ackages/apt/_init_-py
    108%
    Construir y S...
    19s
    lib/python3/dist-packages/apt/cache. py
    478
    -packages/apt/cdrom. py
    /usr/lib/python3/dist-packages/apt/package.py
    728
    496
    Post-job: Che...
    <1s
    ackages/apt/progress/_init_.py
    100%
    Finalize Job
    <1s
    /usr/lib/python3/dist-packages/apt/progress/base.py
    138
    91
    47
    /usr/lib/python3/dist-packages/apt/progress/text. py
    155
    123
    21%
    /usr/lib/python3/dist-packages/problem_report. py
    431
    393
    9%%
    Publicar Artefactos
    48
    49
    11
    91%
    manage . py
    50
    Publicar artefacto...
    3s
    51
    TOTAL
    5182 4360
    16%
    Initialize job
    15
    53
    Finishing: Ejecutar cobertura de pruebas
    Checkout devs...
    Publicar artef...
    Project settings
    5:00:06 AM
    N
    XJ
    A >_
    U N V 4 - - 71
    3/23/2025

[^18]: devsu-dem x J Pipelines -
    I X J Pipelines - X Q kubeseal -
    x ) Release sea X
    Docker Hul X 3 Extensions X New tab x
    C
    https://dev.azure.com/georgexdxd5/devsu-demo/_build/results?buildld =101&view=logs&j=69dd0e97-8f3f-5045-5fbd-coe...
    School..'
    Azure Devops georgexdxd5 / devsu-demo / Pipelines
    / devsu-demo-devops-python / 20250323.5
    Q Search
    GA
    D devsu-demo
    Jobs in run #20250323.5
    Construir y Subir Imagen Docker
    View raw log
    Ejeculdi riuends villianlas
    Overview
    Ejecutar prueba...
    15s
    Boards
    103
    Initialize job
    <1s
    104
    #10 \[5/7\] COPY . .
    105
    #10 DONE 0.0s
    Repos
    Checkout devs...
    1s
    106
    107
    #11 \[6/7\] COPY . env . env
    108
    #11 DONE 0.0s
    Pipelines
    Instalar depe...
    11s
    109
    Ejecutar pruebas
    1s
    110
    #12 \[7/7\] RUN mkdir -p /app/data && chmod -R 755 /app/data
    bid Pipelines
    111
    #12 DONE 0.2s
    Post-job: Che...
    <1s
    112
    Environments
    113
    #13 exporting to image
    Finalize Job
    <1s
    114
    #13 exporting layers
    Releases
    115
    #13 exporting layers 2.2s done
    116
    #13 writing image sha256: c4d82be96659acd4b220a22843d6137ba366f8450483374485911ffc9606d4e1 done
    I Library
    Cobertura de Pruebas
    117
    #13 naming to docker . io/gpaulinoalmonte/myapp-101: latest done
    118 #13 DONE 2.35
    Task groups
    Cobertura de pr..
    10s
    119
    Subiendo la imagen Docker a Docker Hub. . .
    120
    WARNING! Your password will be stored unencrypted in /home/vsts/ . docker/config. json.
    Deployment groups
    Initialize job
    <1s
    21
    Configure a credential helper to remove this warning. See
    122
    https://docs . docker . com/engine/reference/commandline/login/#credentials-store
    Test Plans
    Checkout devs...
    15
    123
    124
    Login Succeeded
    Ejecutar cober...
    Artifacts
    125
    Pushing image gpaulinoalmonte/myapp-101: latest. . .
    126
    The push refers to repository \[docker . io/gpaulinoalmonte/myapp-101\]
    Post-job: Che...
    <1s
    127
    C7f84ea6bb2b: Preparing
    128
    5f70bf18a086: Preparing
    Finalize Job
    1s
    129
    991fff7d15b2: Preparin
    7f5d1975267d: Preparing
    Construir y Subir Imagen Docker
    131
    132
    891c7af451co: P
    Construir y Subi..
    22s
    133
    134
    Obab2844ed8c: Prep
    Initialize job
    <1s
    135
    63693cdb3388: Preparing
    136
    6669ab6e06c6: Preparing
    Checkout devs...
    1s
    137
    8cbe4b54fa88: Preparing
    138
    891c7af451c0: Waiting
    Construir y S...
    19s
    139
    ecf86a50d059: Waiting
    140
    @bab2844ed8c: Waiting
    Post-job: Che...
    <1s
    141
    63693cdb3388: Waiting
    142
    6669ab6e06c6: Waiting
    Finalize Job
    <1s
    143
    8cbe4b54fa88: Waiting
    144
    5f70bf18a086: Pushed
    Publicar Artefactos
    145
    031756bcad6b: Pushed
    146
    C7f84ea6bb2b: Pushed
    V
    Publicar artefacto...
    147
    991fff7d15b2: Pushed
    3s
    148
    ecf86a50d059: Mounted from library/python
    149
    Initialize job
    63693cdb3388: Mounted from library/python
    <1s
    150
    0bab2844ed8c: Mounted from library/python
    151
    Checkout devs...
    891c7af451c0: Pushed
    1s
    152
    6669ab6e06c6: Mounted from library/python
    153
    Publicar artef...
    8cbe4b54fa88: Mounted from library/python
    <1s
    154
    7f5d19752b7d: Pushed
    Post-job: Che...
    155
    latest: digest: sha256: 1f7d18549e808382152904143ade87430b5791b71ce514a28d142821830a314 size: 2617
    <1s
    156
    La imagen Docker se construyo y subio correctamente con el nombre gpaulinoalmonte/myapp-101 : latest
    Finalize Job
    157
    158
    Finishing: Construir y Subir Imagen Docker
    Project settings
    Finalize build
    XI
    A S_
    U N V 4 -
    5:00:19 AM
    3/23/202

[^19]: devsu-dem x \] Pipelines -
    I X J Pipelines -
    X Q kubeseal - x () Release sea X Docker Hul X 3 Extensions X New tab x
    ...
    G
    eorgexdxd5/devsu-demo/_build/results?buildld=101&view=logs&j=70d87c7b-ae91-5344-efc0-96f...
    School
    https://dev.azure.com/georgexax
    GA
    Azure Devops georgexdxd5
    devsu-demo / Pipelines / devsu-demo-devops-python / 20250323.5
    Q Search
    D devsu-demo
    Jobs in run #202...
    UsePythonVersion
    View raw log
    devsu-demo-devops-python
    Overview
    Starting: UsePythonVersion
    Boards
    Preparar el Entorno
    Task
    : Use Python version
    Preparar entorno...
    Description : Use the specified version of Python from the tool cache, optionally adding it to the
    Repos
    Version
    : 0.248.1
    Initialize job
    31s
    Author
    : Microsoft Corporation
    Pipelines
    Help
    : https://docs.microsoft.com/azure/devops/pipelines/tasks/tool/use-python-version
    Checkout devs...
    Pipelines
    ch versions
    Preparar ent...
    <1s
    10
    ## \[warning \]You
    . Otherwise you m
    & Environments
    11
    Downloading: https://github. com/actions/python-versions/releases/download/3. 11.3-11059198104/python-3
    Post-job: Che...
    <1s
    12
    Extracting archive
    Releases
    13
    /usr/bin/tar xC /home/vsts/work/_temp/7dlace83-7670-49f6-alaa-681bc8b5c8fc -f /home/vsts/work/_temp/F
    Finalize Job
    <1s
    14
    In Library
    15
    /usr/bin/bash . /setup. sh
    Instalar Dependencias
    16
    Check if Python hostedtoolcache folder exist...
    Task groups
    17
    Create Python 3.11.3 folder
    Instalar Depend...
    23s
    18
    Copy Python binaries to hostedtoolcache folder
    Deployment groups
    19
    Create additional symlinks (Required for the UsePythonVersion Azure Pipelines task and the setup-pyth
    Initialize job
    15
    20
    Upgrading pip. . .
    Test Plans
    21
    Looking in links: /tmp/tmph65ou7qd
    Checkout devs...
    1s
    22
    Requirement already satisfied: setuptools in /opt/hostedtoolcache/Python/3.11.3/x64/lib/python3.11/si
    23
    Requirement already satisfied: pip in /opt/hostedtoolcache/Python/3.11.3/x64/lib/python3.11/site-pack
    Artifacts
    UsePythonVe...
    14s
    24
    Collecting pip
    25
    Downloading pip-25.0.1-py3-none-any . wh1 (1.8 MB)
    Instalar depen...
    55
    26
    - 1.8/1.8 MB 7.6 MB/s eta 0:00:00
    27
    Installing collected packages: pip
    Post-job: Che...
    <1s
    Attempting uninstall: pip
    Found existing installation: pip 22.3.1
    Finalize Job
    <1s
    Uninstalling pip-22.3.1:
    Successfully uninstalled pip-22.3.1
    Analisis de Codigo con Pylint
    Successfully installed pip-25.0.1
    Create complete file
    34
    V
    Analisis estatico...
    11s
    35
    Found tool in cache: Python 3.11.3 x64
    36
    Prepending PATH environment variable with directory: /opt/hostedtoolcache/Python/3.11.3/x64
    Initialize job
    <1s
    37
    Prepending PATH environment variable with directory: /opt/hostedtoolcache/Python/3.11.3/x64/bin
    38
    Finishing: UsePythonVersion
    Checkout devs...
    Instalar Pylint
    CC
    Ejecutar analisi...
    Post-job: Che...
    <1s
    Finalize Job
    <1
    Ejecutar Pruebas Unitarias
    V
    Ejecutar prueba...
    15s
    Initialize job
    <1s
    Checkout devs...
    1s
    Instalar depe...
    11s
    Project settings
    <<
    4:59:06 AM
    P
    3/23/2025

[^20]: @ @ devsu-dem x Pipelines - \|X \] Pipelines - X Q kubeseal - x () Release sea X
    Docker Hut X 3 Extensions X \| New tab x \|+
    C
    https://hub.docker.com/repositories/gpaulinoalmonte
    (School..
    dockerhub
    Explore
    My Hub
    Q Search Docker Hub
    Ctri+K
    G
    gpaulinoalmonte
    Repositories
    Docker Personal
    All repositories within the gpaulinoalmonte namespace
    Repositories
    Settings
    Search by repository name
    All content
    Create a repository
    Default privacy
    Notifications
    Name
    Last Pushed
    Contains
    Visibility
    Scout
    Billing
    gpaulinoalmonte/myapp-98
    6 minutes ago
    IMAGE
    Public
    Inactive
    h
    Usage
    Pulls
    gpaulinoalmonte/myapp-97
    38 minutes ago
    IMAGE
    Public
    Inactive
    Storage
    gpaulinoalmonte/myapp-96
    about 11 hours ago
    IMAGE
    Public
    Inactive
    gpaulinoalmonte/myapp-94
    about 11 hours ago
    IMAGE
    Public
    Inactive
    gpaulinoalmonte/myapp-91
    6 days ago
    IMAGE
    Public
    Inactive
    gpaulinoalmonte/myapp-90
    6 days ago
    IMAGE
    Public
    Inactive
    gpaulinoalmonte/myapp-89
    6 days ago
    IMAGE
    Public
    Inactive
    gpaulinoalmonte/myapp-20250317024146
    6 days ago
    IMAGE
    Public
    Inactive
    gpaulinoalmonte/myapp-20250317023214
    6 days ago
    IMAGE
    Public
    Inactive
    gpaulinoalmonte/myapp-20250317020333
    6 days ago
    IMAGE
    Public
    Inactive
    1-10 of 10
    By clicking "Accept All Cookies", you agree to the storing of cookies on your device to enhance site navigation, analyze site
    usage, and assist in our marketing efforts.
    Cookies Settings
    Reject All
    X
    Accept All Cookies
    U N V 4 - - 71
    5:01:11 AM
    3/23/2025

[^21]: PowerShell
    X _ PowerShell
    X PowerShell
    X _ PowerShell
    X PowerShell
    > crc stop
    INFO Stopping kubelet and all containers ...
    INFO Stopping the instance, this may take a few minutes ...
    WARN Failed to remove crc contexts from kubeconfig: <nil>
    Stopped the instance
    \~ took 46s
    > crc start
    INFO Using bundle path C: \\Users\\gpaul\\. crc\\cache\\crc_hyperv_4. 18.1_amd64. crcbundle
    INFO Checking minimum RAM requirements
    INFO Check if Podman binary exists in: C: \\Users\\gpaul\\. crc\\bin\\oc
    INFO Checking if running in a shell with administrator rights
    INFO Checking Windows release
    INFO Checking Windows edition
    INFO Checking if Hyper-V is installed and operational
    INFO Checking if Hyper-V service is enabled
    INFO Checking if crc-users group exists
    INFO Checking if current user is in crc-users and Hyper-V admins group
    INFO Checking if vsock is correctly configured
    INFO Checking if the win32 background launcher is installed
    INFO Checking if the daemon task is installed
    INFO Checking if the daemon task is running
    INFO Checking admin helper service is running
    INFO Checking SSH port availability
    INFO Loading bundle: crc_hyperv_4 . 18.1_amd64 ...
    INFO Starting CRC VM for openshift 4. 18.1 ...
    INFO CRC instance is running with IP 127.0.0.1
    INFO CRC VM is running
    INFO Updating authorized keys ...
    INFO Check internal and public DNS query ...
    INFO Check DNS query from host ...
    INFO Verifying validity of the kubelet certificates ...
    INFO Starting kubelet service
    INFO Waiting for kube-apiserver availability ... \[takes around 2min\]
    INFO Waiting until the user's pull secret is written to the instance disk ...
    INFO Starting openshift instance ... \[waiting for the cluster to stabilize\]
    INFO 2 operators are progressing: dns, ingress
    INFO Operator ingress is progressing
    INFO Operator openshift-apiserver is not yet available
    INFO All operators are available. Ensuring stability ...
    INFO Operators are stable (2/3) ...
    INFO Operators are stable (3/3) ...
    INFO Adding crc-admin and crc-developer contexts to kubeconfig ...
    Started the OpenShift cluster.
    The server is accessible via web console at:
    https://console-openshift-console . apps-crc . testing
    Log in as administrator:
    Username: kubeadmin
    Password: daTDE-edzfS-HoHCB-4u2re
    Log in as user:
    Username: developer
    Password: developer
    Use the 'oc' command line interface:
    > aFOR /f "tokens=\*" %i IN ('crc oc-env' ) DO acall %i
    oc login -u developer https: //api. crc. testing:6443
    \~ took 3m46s
    DOP/USD
    Q Search
    9

[^22]: Deployments . Red X @ Page not found at X \|@ devsu-demo-devo x \|@ devsu-demo-devo x \|@ devsu-demo-devo x @ DisallowedHost at. X
    <
    C
    Not secure \| https://console-openshift-console.apps-crc.testing/k8s/ns/devsu-demo/apps\~v1\~Deployment
    (School
    ...
    OpenShift Local cluster is for development and testing purposes. DON'T use it for production.
    Red Hat
    +
    ?
    kubeadmin
    OpenShift
    Project: devsu-demo
    Administrator
    Home
    Deployments
    te Deployment
    Operators
    Name
    Search by name.
    Workloads
    Name
    Status
    Labels
    Pod selector
    Pods
    D devsu-demo-devops-python
    2 of 2 pods
    app.kubernetes.io/inst...=devsu-de...
    Q app=devsu-demo-devops-
    python
    Deployments
    DeploymentConfigs
    StatefulSets
    Secrets
    ConfigMaps
    CronJobs
    Jobs
    DaemonSets
    ReplicaSets
    ReplicationControllers
    HorizontalPodAutoscalers
    PodDisruptionBudgets
    Networking
    Services
    Routes
    Ingresses
    NetworkPolicies
    UserDefinedNetworks
    Storage
    Builds
    Compute
    User Management
    5:04:27 AM
    N
    3/23/2025

[^23]: Deploymen X Page not fo X @ devsu-dem x @ devsu-dem x @ devsu-dem x @ Disallowed x \| Q argocd gitt x () argoproj/a x +
    G
    \* Not secure \| https://console-openshift-console.apps-crc.testing/k8s/ns/argocd/apps\~v1\~Deployment
    (School...
    OpenShift Local cluster is for development and testing purposes. DON'T use it for production
    Red Hat
    +
    ?
    kubeadmin
    OpenShift
    Project: argocd
    Administrator
    Home
    Deployments
    Create Deployment
    Operators
    Name . Search by name...
    Workloads
    Name
    Status
    Labels
    Pod selector
    Pods
    D argocd-applicationset
    1 of 1 pods
    app.kubernetes.io... =applicationset.
    Q app.kubernetes.io/name=argocd-
    controller
    applicationset-controller
    Deployments
    app.kubernet.. =argocd-application.
    DeploymentConfigs
    app.kubernetes.io/part-of=argocd
    StatefulSets
    D argocd-dex-server
    1 of 1 pods
    app.kubernetes.io/comp.. =dex-ser.
    Q app.kubernetes.io/name=argocd-
    dex-server
    Secrets
    app.kubernetes.io. =argocd-dex-s...
    ConfigMaps
    app.kubernetes.io/part-of=argocd
    D argocd-notifications
    1 of 1 pods
    app.kubernetes.io/.=notifications-.
    Q app.kubernetes.io/name=argocd-
    CronJobs
    controller
    notifications-controller
    app.kubernet. =argocd-notification.
    Jobs
    app.kubernetes.io/part-of=argocd
    DaemonSets
    D argocd-redis
    O of O pods
    app.kubernetes.io/component=redis
    Q app.kubernetes.io/name=argocd-
    ReplicaSets
    redis
    app.kubernetes.io/na... =argocd-re.
    ReplicationControllers
    app.kubernetes.io/part-of=argocd
    HorizontalPodAutoscalers
    D argocd-repo-server
    of 1 pods
    app.kubernetes.io/com.. =repo-se..
    app.kubernetes.io/name=argocd-
    PodDisruptionBudgets
    repo-server
    app.kubernetes.io.=argocd-repo-.
    app.kubernetes.io/part-of=argocd
    Networking
    D argocd-server
    2 of 1 pods
    app.kubernetes.io/compon.. =serv.
    Q app.kubernetes.io/name=argocd-
    Services
    server
    app.kubernetes.io/n. =argocd-ser.
    Routes
    app.kubernetes.io/part-of=argocd
    Ingresses
    NetworkPolicies
    UserDefinedNetworks
    Storage
    Builds
    Compute
    User Management
    U N V 4 - - 7(
    5:06:18 AM
    3/23/202

[^24]: D
    Routes . Re X @ Page not fo x @ devsu-dem x @ devsu-dem x @ devsu-dem x \| Disallowed X \| Q argocd gitt X () argoproj/a X
    <
    C
    \* Not secure \| https://console-openshift-console.apps-crc.testing/k8s/ns/argocd/route.openshift.io\~v1\~Route
    (School
    ...
    OpenShift Local cluster is for development and testing purposes. DON'T use it for production.
    Red Hat
    +
    ?
    OpenShift
    kubeadmin
    Project: argocd
    Administrator
    Home
    Routes
    Create Route
    Operators
    Filter
    Name
    Search by name.
    Workloads
    Name
    Status
    Location
    Service
    Pods
    RT argocd-server
    Accepted
    https://argocd-server-
    S argocd-server
    Deployments
    argocd.apps-
    crc.testing & L
    DeploymentConfigs
    StatefulSets
    Secrets
    ConfigMaps
    CronJobs
    Jobs
    DaemonSets
    ReplicaSets
    ReplicationControllers
    HorizontalPodAutoscalers
    PodDisruptionBudgets
    Networking
    Services
    Routes
    ngresses
    NetworkPolicies
    UserDefinedNetworks
    Storage
    Builds
    Compute
    User Management
    N
    5:06:27 AM
    3/23/2025

[^25]: Reposito X \]Pipelines X \] Pipelines X Q kubeseal x () Release x \| Docker X 3 Extension x \| New tab x \| New tab x \| +
    C
    x Not secure\|
    https://console-openshift-console.apps-crc.testing:8080/settings/repos
    School.
    CANCEL
    X
    argo
    2.8.4+c279299
    Applications
    CONNECTED REPOSITORY
    EDIT
    Settings
    Type
    git
    User Info
    Project
    default
    Documentation
    Repository URL
    https://georgexdxd5@dev.azure.com/georgexdxd5/devsu-demo/_git/laC-devsu-test
    Username (optional)
    g.paulino
    Password (optional)
    X H C A S GOPAL
    U N V 4 - - 7(
    5:05:42 AM
    23/2025

[^26]: devsu-de X \] Pipelines X \] Pipelines X
    kubeseal X
    Release : X Docker x 3 Extension X New tab x New tab x \| +
    C
    x Not secure
    https://console-openshift-console.apps-crc.testing:8080/applications/argocd/devsu-demo?view=tree&resource=
    $3 School.
    Applications Q devsu-demo
    APPLICATION DETAILS TREE
    argo
    V2.8.4+c279299
    APP DETAILS
    APP DIFF
    SYNC
    SYNC STATUS
    HISTORY AND ROLLBACK
    DELETE
    C REFRESH
    26 Log out
    Applications
    APP HEALTH
    SYNC STATUS
    LAST SYNC
    Healthy
    + OutOfSync from HEAD (5c32faf)
    Sync OK to 5c32faf
    Settings
    Auto sync is enabled.
    Succeeded 24 minutes ago (Sun Mar 23 2025 04:43:08
    GMT-0400)
    User Info
    Author: George Albert Paulino Almonte <gpaulinoal.
    Author: George Albert Paulino Almonte <gpaulinoal.
    Comment: firts-commit
    Comment: firts-commit
    Documentation
    =D + -
    100%
    NAME
    NAME
    secret-devsu-demo-devops-p...
    ...
    secret
    KINDS
    KINDS
    devsu-demo-devops-python
    ..
    SVC
    SYNC STATUS
    devsu-demo-sa
    Synced
    ..
    +
    OutOfSync
    N
    devsu-demo-devops-python
    ...
    HEALTH STATUS
    devsu-demo
    deploy
    Healthy
    O W
    2 hours
    devsu-demo-cr
    Progressing
    ..
    c-role
    Degraded
    O
    Suspended
    anyuid-cluster-role-binding-de...
    crb
    Missing
    O
    Unknown
    O
    devsu-demo-cr
    ..
    crb
    R
    devsu-demo-devops-python
    ...
    route
    NT
    2 X H C A S GOPPAL
    U N V 4 - - 7()
    5:06:59 AM
    23/2025

[^27]: File Edit Selection View Go Run ...
    laC-devsu-test-1
    0: D 2 0 8 @ GE -
    X
    ML kustomization.yaml .\\devsu-demo\\.
    ML kustomization.yaml ..\\server\\... X \|ML devsu-demo-devops-python.yaml 1
    DOD.
    EXPLORER
    -..
    laC-devsu-test > argocd > server > overlays > test > ML kustomization.yaml > \[ \] resources > \[\] o
    kustomization.yaml - Kubernetes native configuration mal
    IAC-DEVSU-TEST-1
    apiversion: . kustomize . config.k8s. io/vibe
    >secret-devsu-demo-devo\| Aa ab, \* No results TV = x
    laC-devsu-test
    kind : . Kustomization
    argocd
    NOUAWNH
    vi apps\\ devsu-demo
    resources :
    # . Apps
    base
    .-. . ./ . ./ . ./apps/apap-prod/overlays/test
    first commit, George Albert Paulino Almonte (10 \|
    ML app.yaml
    M kustomization.yaml
    M namespace.yaml
    overlays \\ test
    ML kustomization.yaml
    server \\ overlays \\ test
    kustomization.yaml
    pre-produccion \\ namespaces \\ devsu-demo
    base
    ML devsu-demo-devops-python.yaml
    M kustomization.yaml
    overlays \\ test
    patch
    { } devsu-demo-sa-patch.json
    route
    ML devsu-demo-devops-python.yaml
    YL account.yml
    M devsu-demo-sa.yml
    secrets
    \[ devsu-demo-devops-python.env
    \* tools
    M kustomization.yaml
    ML kustomization.yaml
    .gitignore
    My README.md
    OUTLINE
    TIMELINE
    APPLICATION BUILDER
    METADATA
    PROBLEMS 1
    OUTPUT
    DEBUG CONSOLE
    COMMENTS
    ANSIBLE
    TERMINAL
    PORTS
    -v ... X
    PS C:\\Users\\gpaul \\Downloads\\IaC-devsu-test-1> git add .
    pwsh
    PS C: \\Users\\gpaul\\Downloads\\IaC-devsu-test-1> git commit -m "firts-commit"
    \[main 5c32faf\] firts-commit
    PowerShell .
    5 files changed, 282 deletions(-)
    delete mode 100644 IaC-devsu-test/argocd/apps/sealed-secrets/base/app. yam1
    delete mode 100644 IaC-devsu-test/argocd/apps/sealed-secrets/base/kustomization. yaml
    delete mode 100644 IaC-devsu-test/argocd/apps/sealed-secrets/overlays/test/kustomization. yaml
    delete mode 100644 IaC-devsu-test/pre-produccion/namespaces/sealed-secrets/controller. yaml
    PS C: \\Users\\gpaul \\Downloads\\IaC-devsu-test-1> git push
    Enumeratiog objects: 21, done.
    Counting objects: 100% (21/21), done.
    Delta compression using up to 24 threads
    Compressing objects: 100% (5/5), done.
    Writing objects: 100% (11/11), 829 bytes \| 829.00 KiB/s, done.
    Total 11 (delta 1), reused 0 (delta 0), pack-reused 0 (from 0)
    remote: Analyzing objects... (11/11) (3 ms)
    remote: Validating commits... (1/1) done (1 ms)
    remote: Storing packfile. .. done (34 ms)
    remote: Storing index. .. done (31 ms)
    To https://dev. azure.com/georgexdxd5/devsu-demo/_git/TaC-devsu-test
    549d201. .5c32faf main -> main
    PS C: \\Users \\gpaul \\Downloads \\ IaC-devsu-test-1>
    x 89 main\* 0 41
    George Albert Paulino Almonte (10 hours ago) Ln 6, Col 42 Spaces: 2 UTF-8 CRLF () YAML & kustomization.yaml w/ Prettier
    A 2
    5:07:40 AM
    3/23/2025

[^28]: devsu-dem x @ Page not fo X @ devsu-dem x @devsu-dem x \|@ devsu-dem x @ Disallowed x \| Q argocd gitt X
    argoproj/a x +
    \* Not secure \| https://console-openshift-console.apps-crc.testing/k8s/ns/devsu-demo/deployments/devsu-demo-devops-python
    (School
    ...
    OpenShift Local cluster is for development and testing purposes. DON'T use it for production.
    Red Hat
    +
    ?
    kubeadmin
    OpenShift
    Project: devsu-demo
    \* Administrator
    Deployments > Deployment details
    Home
    D devsu-demo-devops-python
    Actions
    Operators
    Details
    Metrics
    YAML
    ReplicaSets
    Pods
    Environment
    Events
    Workloads
    Deployment details
    Pods
    Deployments
    DeploymentConfigs
    Pods
    StatefulSets
    Secrets
    Name
    Update strategy
    ConfigMaps
    devsu-demo-devops-python
    RollingUpdate
    CronJobs
    Namespace
    Max unavailable
    NS devsu-demo
    25% of 2 pods
    Jobs
    Edit
    DaemonSets
    Labels
    Max surge
    25% greater than 2 pods
    ReplicaSets
    app.kubernetes.io/instance=devsu-demo
    ReplicationControllers
    Progress deadline seconds
    Pod selector
    600 seconds
    HorizontalPodAutoscalers
    Q app=devsu-demo-devops-python
    Min ready seconds
    PodDisruptionBudgets
    Node selector
    Not configured
    No selector
    Networking
    PodDisruptionBudget
    Tolerations
    No PodDisruptionBudget
    Services
    tolerations
    Routes
    VerticalPodAutoscalers
    Annotations
    No VerticalPodAutoscalers
    Ingresses
    2 annotations
    NetworkPolicies
    Status
    UserDefinedNetworks
    Up to date
    Storage
    Created at
    3 Mar 23, 2025, 2:46 AM
    Builds
    Owner
    No owner
    Compute
    User Management
    5:09:22 AM
    N
    3/23/2025

[^29]: PowerShell
    PowerShell
    X > PowerShell
    X PowerShell
    X
    PowerShell
    PowerShell 7.5.0
    Loading personal and system profiles took 866ms.
    > kubectl apply -f https: //github. com/bitnami-labs/sealed-secrets/releases/download/v0. 28.0/controller. yaml
    deployment . apps/sealed-secrets-controller created
    service/sealed-secrets-controller-metrics created
    rolebinding . rbac . authorization . k8s . io/sealed-secrets-controller created
    clusterrolebinding . rbac . authorization . k8s . io/sealed-secrets-controller created
    serviceaccount/sealed-secrets-controller created
    customresourcedefinition . apiextensions . k8s . io/sealedsecrets . bitnami . com created
    service/sealed-secrets-controller created
    rolebinding . rbac . authorization . k8s . io/sealed-secrets-service-proxier created
    role. rbac . authorization. k8s . io/sealed-secrets-service-proxier created
    role . rbac . authorization . k8s . io/sealed-secrets-key-admin created
    clusterrole . rbac . authorization . k8s . io/secrets-unsealer created
    5:09:38 AM
    3/23/2025

[^30]: < File Edit Selection View Go Run
    ...
    laC-devsu-test-1
    8v
    0: 1 2 0 8 GE
    X
    ML kustomization.yaml .\\devsu-demo\\.
    X
    ML kustomization.yaml .\\server\\.
    ML devsu-demo-devops-python.yaml 1
    DOO..
    EXPLORER
    ...
    laC-devsu-test > pre-produccion > namespaces > devsu-demo > overlays > test > ML kustomization.yaml > \[ \] secretGenerator > {} 0 > \[ \] literals >
    IAC-DEVSU-TEST-1
    > secret-devsu-demo-devo\| Aa ab _\* ? of 1
    VEX
    laC-devsu-test
    kustomization.yaml - Kubernetes native configuration management (kustomization.json)
    vargocd
    kind : . Kustomization
    WNP
    apiVersion: . kustomize . config. k8s. io/vibetal
    v apps \\ devsu-demo
    namespace : . devsu-demo
    base
    ML app.yaml
    nut
    resources :
    M kustomization.yaml
    . . . - . sa/account . ym\]
    namespace.yaml
    . . . - . sa/devsu-demo-sa. yml
    overlays \\ test
    8
    . . . - . route/devsu-demo-devops-python . yaml
    9
    . . - . tools
    kustomization.yaml
    10
    v server \\ overlays \\ test
    11
    secretGenerator:
    kustomization.yaml
    12
    . . . . - . name : "secret-devsu-demo-devops-pythoni
    pre-produccion \\ namespaces \\ devsu-demo
    13
    . . . .. . literals:
    base
    14
    . . . .. . . .. . - PORT=8080
    ML devsu-demo-devops-python.yaml
    15
    . . . .. . . .. - . DATABASE_NAME=/app/data/dev . sqlite
    firts-commit, George Albert Paulino Almonte
    16
    . . . .. . . ..- - - DATABASE_USER=user
    M kustomization.yaml
    17
    . - . DATABASE_PASSWORD=password
    overlays \\ test
    18
    \|. - . NODE_ENV=production
    patch
    19
    () devsu-demo-sa-patch.json
    route
    M devsu-demo-devops-python.yaml
    sa
    ML account.yml
    A devsu-demo-sa.yml
    secrets
    devsu-demo-devops-python.env
    \*tools
    M kustomization.yaml
    kustomization.yaml
    .gitignore
    My README.md
    OUTLINE
    TIMELINE
    APPLICATION BUILDER
    METADATA
    PROBLEMS 1
    OUTPUT DEBUG CONSOLE
    COMMENTS
    ANSIBLE
    TERMINAL
    PORTS

[^31]: secret- X @ Pagen X @ devsu- X @ devsu- x \|@ devsu- x Disallo X \| Q argocc X () argop X Q kubest X
    ) Releas x \|+
    C
    \* Not secure \| https://console-openshift-console.apps-crc.testing/k8s/ns/devsu-demo/secrets/secret-devsu-demo-devops-python...
    (School
    ...
    OpenShift Local cluster is for development and testing purposes. DON'T use it for production.
    Red Hat
    A
    +
    ?
    OpenShift
    kubeadmin
    Project: devsu-demo
    Administrator
    secret-devsu-demo-devops-python-6hgtt2469g
    Opaque
    Home
    Namespace
    NS devsu-demo
    Operators
    Labels
    Edit
    Workloads
    app.kubernetes.io/instance=devsu-demo
    Pods
    Annotations
    Deployments
    1 annotation
    DeploymentConfigs
    Created at
    StatefulSets
    3 Mar 23, 2025, 4:42 AM
    Secrets
    Owner
    ConfigMaps
    No owner
    CronJobs
    Data
    & Hide values
    Jobs
    DaemonSets
    DATABASE_NAME
    ReplicaSets
    ReplicationControllers
    /app/data/dev . sqlite
    HorizontalPodAutoscalers
    DATABASE_PASSWORD
    PodDisruptionBudgets
    Networking
    password
    Services
    DATABASE_USER
    Routes
    Ingresses
    user
    NetworkPolicies
    UserDefinedNetworks
    NODE_ENV
    Storage
    production
    Builds
    PORT
    Compute
    8000
    User Management
    N
    XJ
    A 2
    5:12:06 AM
    /23/2025

[^32]: D
    secret- X @ Pagen X @ devsu- X @ devsu- x \|@ devsu- X @ Disallo X \| Q argocc X () argop X
    Q kubest X () Releas X
    <
    C
    \* Not secure \| https://console-openshift-console.apps-crc.testing/k8s/ns/devsu-demo/secrets/secret-devsu-demo-devops-python..
    (School
    ...
    OpenShift Local cluster is for development and testing purposes. DON'T use it for production.
    Red Hat
    A
    +
    ?
    kubeadmin
    OpenShift
    Project: devsu-demo
    Administrator
    Secrets > Secret details
    Home
    s secret-devsu-demo-devops-python-6hgtt2469g
    Add Secret to workload
    Actions
    Operators
    Details
    YAML
    Workloads
    Secret details
    Pods
    Name
    Type
    Deployments
    secret-devsu-demo-devops-python-6hgtt2469g
    Opaque
    DeploymentConfigs
    Namespace
    StatefulSets
    NS devsu-demo
    Secrets
    Labels
    Edit
    ConfigMaps
    app.kubernetes.io/instance=devsu-demo
    CronJobs
    Annotations
    Jobs
    annotation
    DaemonSets
    Created at
    ReplicaSets
    3 Mar 23, 2025, 4:42 AM
    ReplicationControllers
    Owner
    HorizontalPodAutoscalers
    No owner
    PodDisruptionBudgets
    Networking
    Data
    & Hide values
    Services
    DATABASE_NAME
    Routes
    Ingresses
    /app/data/dev . sqlite
    NetworkPolicies
    DATABASE_PASSWORD
    UserDefinedNetworks
    Storage
    password
    Builds
    DATABASE_USER
    Compute
    user
    User Management
    NODE ENV
    P
    5:12:27 AM
    3/23/2025

[^33]: D
    devsu- x @ Pagen X @ devsu- X @ devsu- x @ devsu- X Disallo X \| Q argocc X () argop X
    Q kubest X () Releas X
    <
    C
    \* Not secure \| https://console-openshift-console.apps-crc.testing/k8s/ns/devsu-demo/deployments/devsu-demo-devops-python/...
    (School
    ...
    OpenShift Local cluster is for development and testing purposes. DON'T use it for production.
    Red Hat
    A
    +
    ?
    kubeadmin
    OpenShift
    Project: devsu-demo
    Administrator
    Deployments > Deployment details
    Home
    D devsu-demo-devops-python
    Actions
    Operators
    Details
    Metrics
    YAML
    ReplicaSets
    Pods
    Environment
    Events
    Workloads
    Container:
    C devsu-demo-devops-python
    Pods
    Deployments
    Single values (env) @
    DeploymentConfigs
    Name
    Value
    Value
    StatefulSets
    Name
    Secrets
    Add more + Add from ConfigMap or Secret
    ConfigMaps
    CronJobs
    All values from existing ConfigMaps or Secrets (envFrom) @
    Jobs
    ConfigMap/Secret
    Prefix (optional)
    DaemonSets
    S secret-devsu-demo-devops-python-6hgtt2469g
    ReplicaSets
    + Add all from ConfigMap or Secret
    ReplicationControllers
    HorizontalPodAutoscalers
    PodDisruptionBudgets
    Save
    Reload
    Networking
    Services
    Routes
    Ingresses
    NetworkPolicies
    UserDefinedNetworks
    Storage
    Builds
    Compute
    User Management
    5:12:38 AM
    - U N V 4 - - 71
    3/23/2025

[^34]: D
    devsu- x @ Pagen X @ devsu- X @ devsu- x @ devsu- X Disallo X \| Q argocc X () argop X Q kubest X () Releas X
    <
    C
    < Not secure \| https://console-openshift-console.apps-crc.testing/k8s/ns/devsu-demo/pods/devsu-demo-devops-python-d8648d...
    (School
    ...
    OpenShift Local cluster is for development and testing purposes. DON'T use it for production.
    Red Hat
    A
    +
    ?
    kubeadmin
    OpenShift
    Project: devsu-demo
    Administrator
    Pods > Pod details
    Home
    P devsu-demo-devops-python-d8648d668-nkzwh @ Running
    Actions
    Operators
    Details
    Metrics
    YAML
    Environment
    Logs
    Events
    Terminal
    Workloads
    Connecting to C devsu-demo-devops-python
    Expand
    Pods
    Deployments
    # printenv
    DATABASE_USER=user
    DeploymentConfigs
    KUBERNETES_SERVICE_PORT=443
    KUBERNETES_PORT=tcp://10.217.4.1:443
    StatefulSets
    HOSTNAME=devsu-demo-devops-python-d8648d668-nkzwh
    PYTHON_PIP_VERSION=22.3.1
    Secrets
    PORT=8000
    HOME=/root
    ConfigMaps
    DATABASE_NAME=/app/data/dev . sqlite
    GPG_KEY=A035C8C19219BA821ECEA86B64E628F8D684696D
    DEVSU_DEMO_DEVOPS_PYTHON_PORT_8000_TCP_ADDR=10.217.4.173
    CronJobs
    PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/0d8570dc44796f4369b652222cf176b3db6ac70e/public/get-pip.
    py
    Jobs
    TERM=xterm
    KUBERNETES_PORT_443_TCP_ADDR=10.217.4.1
    DaemonSets
    DEVSU_DEMO_DEVOPS_PYTHON_PORT_8000_TCP_PORT=8000
    DEVSU_DEMO_DEVOPS_PYTHON_PORT_8000_TCP_PROTO=tcp
    ReplicaSets
    PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    KUBERNETES_PORT_443_TCP_PORT=44:
    ReplicationControllers
    KUBERNETES_PORT_443_TCP_PROTO=tcp
    DEVSU_DEMO_DEVOPS_PYTHON_SERVICE_HOST=10.217.4.173
    HorizontalPodAutoscalers
    LANG=C.UTF-8
    DEVSU_DEMO_DEVOPS_PYTHON_PORT_8000_TCP=tcp://10.217.4.173:8000
    PodDisruptionBudgets
    PYTHON_VERSION=3. 11.3
    PYTHON_SETUPTOOLS_VERSION=65.5.1
    Networking
    KUBERNETES_SERVICE_PORT_HTTPS-443
    KUBERNETES_PORT_443_TCP=tcp://10.217.4.1:443
    DEVSU_DEMO_DEVOPS_PYTHON_SERVICE_PORT=8000
    Services
    DEVSU_DEMO_DEVOPS_PYTHON_PORT=tcp://10.217.4.173:8000
    KUBERNETES_SERVICE_HOST=10.217.4.1
    Routes
    PWD=/app
    PYTHON_GET_PIP_SHA256-96461deced5c2a487ddc65207ec5a9cffecald34e7af7ealafc470ff0d746207
    Ingresses
    DATABASE_PASSWORD=password
    NSS_SDB_USE_CACHE=no
    NetworkPolicies
    NODE_ENV=production
    UserDefinedNetworks
    Storage
    Builds
    Compute
    User Management
    5:16:35 AM
    N
    2 x
    3/23/2025

[^35]: devsu- X @ Pagen X @ devsu- x @ devsu- x @ devsu- x Disallo X \| Q argocc X () argop x Q kubest x () Releas X +
    0
    C
    Not secure \| https://console-openshift-console.apps-crc.testing/k8s/ns/devsu-demo/pods/devsu-demo-devops-python-d8648d.
    School
    ...
    OpenShift Local cluster is for development and testing purposes. DON'T use it for production.
    Red Hat
    +
    ?
    kubeadmin
    OpenShift
    Project: devsu-demo
    \* Administrator
    Pods > Pod details
    Home
    P devsu-demo-devops-python-d8648d668-nkzwh @ Running
    Actions
    Operators
    Details
    Metrics
    YAML
    Environment
    Logs
    Events
    Terminal
    Workloads
    Log streaming.
    C devsu-demo-devops-python
    Current log
    Q Search
    Pods
    O Show full log
    O Wrap lines
    Raw
    Download
    Expand
    Deployments
    41 lines
    DeploymentConfigs
    Watching for file changes with StatReloader
    StatefulSets
    \[23/Mar/2025 08:45:36\] "GET /admin HTTP/1.1" 301 0
    \[23/Mar/2025 08:45:36\] "GET /admin/ HTTP/1.1" 302 0
    Secrets
    \[23/Mar/2025 08:45:36\] "GET /admin/login/?next=/admin/ HTTP/1.1" 200 4181
    \[23/Mar/2025 08:45:41\] "GET /admin HTTP/1.1" 301 0
    ConfigMaps
    \[23/Mar/2025 08:45:41\] "GET /admin/ HTTP/1.1" 302 0
    \[23/Mar/2025 08:45:41\] "GET /admin/login/?next=/admin/ HTTP/1.1" 200 4181
    8
    \[23/Mar/2025 08:45:46\] "GET /admin HTTP/1.1" 301 0
    CronJobs
    9
    \[23/Mar/2025 08:45:46\] "GET /admin/ HTTP/1.1" 302 0
    10
    \[23/Mar/2025 08:45:46\] "GET /admin/login/?next=/admin/ HTTP/1.1" 200 4181
    Jobs
    11
    \[23/Mar/2025 08:45:47\] "GET /admin HTTP/1.1" 301 0
    12
    \[23/Mar/2025 08:45:47\] "GET /admin/ HTTP/1.1" 302 0
    DaemonSets
    13
    \[23/Mar/2025 08:45:47\] "GET /admin/login/?next=/admin/ HTTP/1.1" 200 4181
    14
    ReplicaSets
    \[23/Mar/2025 08:45:47\] "GET /admin HTTP/1.1" 301 0
    15
    \[23/Mar/2025 08:45:47\] "GET /admin/ HTTP/1.1" 302 0
    ReplicationControllers
    16
    \[23/Mar/2025 08:45:47\] "GET /admin/login/?next=/admin/ HTTP/1.1" 200 4181
    17
    \[23/Mar/2025 08:45:47\] "GET /admin HTTP/1.1" 301 0
    HorizontalPodAutoscalers
    18
    \[23/Mar/2025 08:45:47\] "GET /admin/ HTTP/1.1" 302 0
    19
    \[23/Mar/2025 08:45:47\] "GET /admin/ login/?next=/admin/ HTTP/1.1" 200 4181
    PodDisruptionBudgets
    20
    \[23/Mar/2025 08:45:49\] "GET /admin HTTP/1.1" 301 0
    21
    \[23/Mar/2025 08:46:04\] "GET /admin HTTP/1.1" 301 0
    22
    \[23/Mar/2025 08:46:04\] "GET /admin/ HTTP/1.1" 302 0
    Networking
    23
    \[23/Mar/2025 08:46:04\] "GET /admin/login/?next=/admin/ HTTP/1.1" 200 4181
    24
    \[23/Mar/2025 08:46:04\] "GET /admin HTTP/1.1" 301 0
    Services
    25
    \[23/Mar/2025 08:46:04\] "GET /admin/ HTTP/1.1" 302 0
    26
    \[23/Mar/2025 08:46:04\] "GET /admin/login/?next=/admin/ HTTP/1.1" 200 4181
    Routes
    27
    \[23/Mar/2025 08:46:04\] "GET /admin HTTP/1.1" 301 0
    28
    \[23/Mar/2025 08:46:04\] "GET /admin/ HTTP/1.1" 302 0
    Ingresses
    29
    \[23/Mar/2025 08:46:04\] "GET /admin/login/?next=/admin/ HTTP/1.1" 200 4181
    30
    Not Found: /user
    NetworkPolicies
    31
    \[23/Mar/2025 08:46:07\] "GET /user HTTP/1.1" 404 2218
    32
    Not Found: /user
    UserDefinedNetworks
    33
    \[23/Mar/2025 08:46:08\] "GET /user HTTP/1.1" 404 2218
    34
    Not Found: /users
    35
    \[23/Mar/2025 08:46:11\] "GET /users HTTP/1.1" 404 2221
    Storage
    36
    Not Found: /users
    37
    \[23/Mar/2025 08:46:12\] "GET /users HTTP/1.1" 404 2221
    38
    Not Found: /
    Builds
    39
    \[23/Mar/2025 08:46:17\] "GET / HTTP/1.1" 404 2188
    40
    \[23/Mar/2025 08:46:19, 088\] - Broken pipe from ('10.217.0.2' , 52428)
    A1
    \[23/Mar/2025 08:46:19,089\] - Broken pipe from ('10.217.0.2' , 42954)
    Compute
    User Management
    5:13:09 AM
    N
    P
    U N V 4 - - 74
    /23/2025

[^36]: devsu- x @ Pagen X @ Pagen X @ devsu- X @ devsu- x Disallo x \| Q argocc X () argop x Q kubest x () Releas x \|+
    0
    X
    A Not secure \| devsu-demo-devops-python.apps-crc.testing
    School
    Page not found (404)
    Request Method: GET
    Request URL: http://devsu-demo-devops-python.apps-crc.testing/
    Using the URLconf defined in demo. urls, Django tried these URL patterns, in this order:
    1. admin
    2. api/
    The empty path didn't match any of these
    You're seeing this error because you have DEBUG = True in your Django settings file. Change that to False, and Django will display a standard 404 page.
    5:23:00 AM
    3/23/2025

[^37]: 1 Lon streaming
    devell-d
    E
    Home Workspaces
    API Network
    Q Search Postman
    #+ Invite
    Upgrade
    X
    My Workspace
    New
    Import
    60 Overview
    POST http://127.0.0.1:8000/a . GET http://devsu-demo-dev .
    +
    No environment
    V
    HTTP http://devsu-demo-devops-python.apps-crc.testing/api
    Save
    Share
    Collections
    Globals
    GET
    http://devsu-demo-devops-python.apps-crc.testing/api
    Send
    Environments
    Params
    Authorization
    Headers (8)
    Body
    Scripts
    Tests
    Settings
    Cookies
    Flows
    Query Params
    Key
    Value
    Description
    Bulk Edit
    eb d
    APIS
    Key
    Value
    Description
    History
    You don't have any environments.
    An environment is a set of variables that allows
    you to switch the context of your requests.
    Create Environment
    Body Cookies (2) Headers (10) Test Results
    200 OK . 4 ms . 394 B .()
    000
    73
    {} JSON
    Preview
    Visualize
    v
    STx1
    MOC
    "users": "http://devsu-demo-devops-python . apps-crc. testing/api/users/"
    e ma
    Repo
    tes
    Online O. Find and replace \] Console
    Postbot _Runner Start Proxy @ Cookies Vault Wj Trash 8:
    JO
    NOL rounU.

[^38]: DspicymentContize
    Watching for
    Lon streaming
    devsy
    Home Workspaces
    API Network
    Q Search Postman
    #+ Invite
    Upgrade
    X
    My Workspace
    New
    Import
    60 Overview
    POST http://127.0.0.1:8000/a . GET http://devsu-demo-dev .
    No environment
    HTTP http://devsu-demo-devops-python.apps-crc.testing/admin
    Save
    Share
    Collections
    Globals
    GET
    http://devsu-demo-devops-python.apps-crc.testing/admin
    Send
    Environments
    Params
    Authorization
    Headers (8)
    Body
    Scripts
    Tests
    Settings
    Cookies
    Flows
    Query Params
    Key
    Value
    Description
    Bulk Edit
    APIS
    Key
    Value
    Description
    History
    You don't have any environments.
    An environment is a set of variables that allows
    you to switch the context of your requests.
    Create Environment
    Body
    Cookies (2) Headers (12) Test Results
    200 OK . 6 ms . 4.62 KB
    000
    3/ HTML
    Preview
    Visualize
    4
    5
    <head>
    16
    title> Log in \| Django site admin</title>
    17
    <link rel="stylesheet" href="/static/admin/css/base. css">
    8
    <link rel="stylesheet" href="/static/admin/css/dark_mode. css">
    10
    <script src="/static/admin/js/theme. is" defer></script>
    11
    12
    13
    <link rel="stylesheet" href="/static/admin/css/nav_sidebar. css">
    14
    <script src="/static/admin/js/nav_sidebar. js" defer></script>
    E Online O. Find and replace & Console
    Postbot _ Runner Start Proxy @ Cookies @ Vault \] Trash

