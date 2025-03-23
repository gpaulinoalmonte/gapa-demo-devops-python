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

# Establecer variables de entorno
#ENV NODE_ENV=production
#ENV PORT=3000
#ENV DATABASE_NAME=/app/data/dev.sqlite
#ENV DATABASE_USER=user
#ENV DATABASE_PASSWORD=password

# Añadir permisos solo si es necesario para depuración
RUN mkdir -p /app/data && chmod -R 755 /app/data

EXPOSE 8000

# Comando para ejecutar el servidor
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
