# 🌿 Estrategia de Ramas

## 📋 Descripción

Este proyecto usa una estrategia de dos ramas principales:

- **`master` / `main`**: Desarrollo y testing (sin deploy automático)
- **`web`**: Producción (con deploy automático a EC2)

## 🔄 Flujo de Trabajo

### 1. Desarrollo (Branch master/main)

```bash
# Trabaja en master/main normalmente
git checkout master
git add .
git commit -m "New feature"
git push origin master
```

**Resultado:** 
- ✅ Código se sube al repositorio
- ❌ NO se despliega automáticamente
- ✅ Puedes desarrollar y testear sin afectar producción

### 2. Publicar a Producción (Branch web)

```bash
# Cuando estés listo para desplegar
git checkout web
git merge master  # O cherry-pick commits específicos
git push origin web
```

**Resultado:**
- ✅ GitHub Actions se ejecuta automáticamente
- ✅ Entrena el modelo
- ✅ Construye Docker
- ✅ Despliega en EC2
- ✅ Expone la API públicamente

### 3. Deploy Manual (Desde cualquier branch)

También puedes ejecutar el workflow manualmente:

1. Ve a GitHub → **Actions**
2. Selecciona "Deploy to AWS EC2"
3. Click en **"Run workflow"**
4. Elige el branch y ejecuta

## 🎯 Ejemplo de Uso

### Desarrollo Local
```bash
# Trabajas en master
git checkout master
# ... hace cambios ...
git commit -m "Fix bug"
git push origin master
# ✅ No despliega
```

### Despliegue a Producción
```bash
# Cuando esté listo para producción
git checkout web
git merge master
git push origin web
# ✅ Despliega automáticamente a EC2
```

## 📝 Buenas Prácticas

1. **Desarrolla en master**: Haz todos tus cambios y commits en master
2. **Testa localmente**: Asegúrate de que todo funcione antes de mergear a web
3. **Mergea a web solo cuando esté listo**: web es producción, no uses para desarrollo
4. **Usa commits descriptivos**: Facilita el tracking de qué se desplegó

## 🔍 Verificar Deploys

Después de hacer push a `web`:

1. Ve a **Actions** en GitHub
2. Verás el workflow ejecutándose
3. Al finalizar, obtendrás la URL de la API desplegada

## 🛠️ Configuración Inicial

Si la rama `web` no existe:

```bash
# Crear rama web desde master
git checkout master
git checkout -b web
git push origin web
```

Ahora `web` está lista para recibir deploys automáticos.

