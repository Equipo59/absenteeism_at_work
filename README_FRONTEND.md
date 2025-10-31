# 🌐 Frontend Web Interface

## 📋 Descripción

Interfaz web HTML/CSS que se sirve desde el mismo servidor FastAPI, permitiendo:

- ✅ Ver el estado de salud de la API
- ✅ Hacer predicciones mediante un formulario interactivo
- ✅ Ver resultados de forma visual

## 🔒 Seguridad

- ✅ Frontend y API en el mismo servidor (mismo origen)
- ✅ CORS configurado para permitir comunicación local
- ✅ Solo comunicación entre frontend y servicio (mismo EC2)
- ✅ Página pública accesible desde internet

## 📁 Estructura

```
absenteeism_at_work/
  static/
    index.html    # Página principal
    style.css     # Estilos
    script.js     # JavaScript para llamadas API
```

## 🌐 Acceso

Una vez desplegada la API, accede a:

- **Frontend**: `http://<EC2-IP>:8000/`
- **API Docs**: `http://<EC2-IP>:8000/docs`
- **Health Check**: `http://<EC2-IP>:8000/health`

## ✨ Características

### Health Check Automático
- Verifica el estado de la API cada 30 segundos
- Muestra si el modelo está cargado
- Indicador visual (verde/amarillo/rojo)

### Formulario de Predicción
- Todos los campos requeridos con validación
- Botón "Fill Example" para datos de ejemplo
- Validación del lado del cliente

### Resultados Visuales
- Muestra la predicción de forma destacada
- Información del modelo utilizado
- Manejo de errores con mensajes claros

## 🎨 Diseño

- Diseño moderno y responsive
- Compatible con móviles y tablets
- Animaciones suaves
- Feedback visual inmediato

## 🔄 Flujo de Uso

1. Usuario accede a `http://<EC2-IP>:8000/`
2. Ve el estado de salud de la API
3. Completa el formulario (o usa "Fill Example")
4. Hace click en "Predict Absenteeism"
5. Ve el resultado en horas predichas
6. Puede hacer nuevas predicciones

## 📝 Campos del Formulario

Todos los campos son requeridos y tienen validación:

- **Reason for Absence**: Selector con opciones comunes
- **Month of Absence**: 0-12 (0 = Unknown)
- **Day of the Week**: 2-6 (Monday-Friday)
- **Season**: 1-4 (Winter, Spring, Summer, Fall)
- **Transportation Expense**: Número positivo
- **Distance from Residence to Work**: En km
- **Service Time**: Años de servicio
- **Age**: Edad del empleado
- **Work Load Average/day**: Carga de trabajo
- **Hit Target**: Porcentaje (0-100)
- **Disciplinary Failure**: Sí/No
- **Education**: Nivel educativo
- **Son**: Número de hijos
- **Social Drinker**: Sí/No
- **Social Smoker**: Sí/No
- **Pet**: Número de mascotas
- **Weight**: Peso en kg
- **Height**: Altura en cm
- **Body Mass Index**: BMI

## 🚀 Despliegue

El frontend se incluye automáticamente en el despliegue. No requiere configuración adicional.

Cuando el workflow de GitHub Actions despliega:
1. Copia los archivos estáticos al EC2
2. FastAPI sirve automáticamente `/static/`
3. La ruta `/` muestra la página HTML

## 🔧 Troubleshooting

### No se muestra la página
- Verifica que `absenteeism_at_work/static/index.html` existe
- Revisa los logs del contenedor: `docker-compose logs`

### Errores de CORS
- El frontend y API están en el mismo servidor, no debería haber problemas
- Si hay errores, verifica que FastAPI está sirviendo los archivos estáticos

### La predicción no funciona
- Verifica que el modelo está cargado (health check)
- Revisa la consola del navegador (F12) para errores
- Verifica que la API responde en `/predict`

