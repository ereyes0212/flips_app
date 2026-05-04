# Integración REST con Dio + Provider

## Dependencias
- dio
- flutter_secure_storage

## cURL de prueba
```bash
curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d '{"nombre":"Ana","email":"ana@mail.com","password":"123456"}'
curl -X POST http://localhost:3000/api/auth/login -H "Content-Type: application/json" -d '{"email":"ana@mail.com","password":"123456"}'
curl -X GET http://localhost:3000/api/mi-perfil -H "Authorization: Bearer <TOKEN>"
curl -X PATCH http://localhost:3000/api/mi-perfil -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"nombre":"Ana 2"}'
curl -X POST http://localhost:3000/api/mi-perfil/password -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"currentPassword":"123456","newPassword":"654321"}'
curl -X GET http://localhost:3000/api/checkout -H "Authorization: Bearer <TOKEN>"
curl -X POST http://localhost:3000/api/checkout -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"estado":"nuevo","items":[]}'
curl -X PUT http://localhost:3000/api/checkout -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"estado":"actualizado","items":[]}'
curl -X GET http://localhost:3000/api/paquetes -H "Authorization: Bearer <TOKEN>"
curl -X GET http://localhost:3000/api/suscripcion-activa -H "Authorization: Bearer <TOKEN>"
curl -X GET http://localhost:3000/api/mis-suscripciones -H "Authorization: Bearer <TOKEN>"
curl -X GET http://localhost:3000/api/mis-facturas -H "Authorization: Bearer <TOKEN>"
curl -X GET http://localhost:3000/api/mis-pagos -H "Authorization: Bearer <TOKEN>"
curl -X GET http://localhost:3000/api/mis-notas -H "Authorization: Bearer <TOKEN>"
```
