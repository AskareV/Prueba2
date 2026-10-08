# Llave de firma de pruebas

`pruebas.keystore` firma el APK que genera GitHub Actions. Siempre es la misma
llave, así que cada APK nuevo se instala **encima** del anterior sin desinstalar
y sin perder datos guardados.

- Alias: `pruebas`
- Contraseña: `pruebas123`

Es pública (está en este repositorio), así que **solo sirve para pruebas**.
Para publicar en Play Store hay que crear una llave nueva y guardarla como
secreto de GitHub, nunca en el repositorio.

El archivo `.gdignore` hace que Godot ignore esta carpeta.
