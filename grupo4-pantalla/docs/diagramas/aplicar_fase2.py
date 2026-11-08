#!/usr/bin/env python3
'''Organiza fotos originales y actualiza enlaces/índices después de descomprimir la fase H2.

Ejecutar: python3 grupo4-pantalla/docs/diagramas/aplicar_fase2.py
Desde cualquier directorio. No hace commits ni toca carpetas de otros grupos.
'''
from pathlib import Path
import shutil
import subprocess

here=Path(__file__).resolve()
root=here.parents[3]
group=root/'grupo4-pantalla'
docs=group/'docs'
photo=docs/'fotos'
target=photo/'01_identificacion_hardware'
if not (root/'.git').exists() or not (group/'README.md').is_file():
    raise SystemExit('ERROR: el script debe estar dentro del repositorio Git, en grupo4-pantalla/docs/diagramas/.')

names=['01-vista-posterior-completa.jpg','02-modelo-y-alimentacion.jpg',
       '03-serigrafia-conector-hub75e.jpg','04-conector-adicional.jpg']
# Validación preventiva: ninguno de los archivos debe faltar ni estar duplicado.
for name in names:
    source=photo/name
    dest=target/name
    if source.is_file() and dest.is_file():
        raise SystemExit(f'ERROR: conflicto; existen ambas rutas para {name}. Ningún archivo ha sido movido.')
    if not source.is_file() and not dest.is_file():
        raise SystemExit(f'ERROR: falta la imagen original {name}. Ningún archivo ha sido movido.')

for name in names:
    source=photo/name
    dest=target/name
    if source.is_file():
        target.mkdir(parents=True,exist_ok=True)
        shutil.move(str(source),str(dest))
        print('Movida:',source.relative_to(root),'→',dest.relative_to(root))

ident=docs/'01-identificacion-panel.md'
text=ident.read_text(encoding='utf-8')
for name in names:
    old='fotos/'+name
    new='fotos/01_identificacion_hardware/'+name
    text=text.replace(old,new)
ident.write_text(text,encoding='utf-8')
print('Actualizados enlaces en',ident.relative_to(root))

def append_once(path,tag,addition):
    t=path.read_text(encoding='utf-8')
    if tag not in t:
        path.write_text(t.rstrip()+'\n\n'+addition.strip()+'\n',encoding='utf-8')
        print('Índice actualizado:',path.relative_to(root))
    else:print('Ya contenía el índice:',path.relative_to(root))

append_once(group/'README.md','## Entregables H2 — diagramas conceptuales', '''
## Entregables H2 — diagramas conceptuales

Se prepararon cinco diagramas editables de arquitectura, flujo, FSM, temporización y framebuffer. **Son propuestas de diseño y no pruebas de funcionamiento.** Cada uno tiene explicación técnica individual en [docs/diagramas/](docs/diagramas/README.md); existe además un índice de [fotografías y evidencias](docs/fotos/README.md). El contacto `NC` y el barrido real deben verificarse antes del conexionado definitivo y del RTL físico de filas.
''')
append_once(docs/'README.md','## Diagramas conceptuales H2 y registro de evidencias', '''
## Diagramas conceptuales H2 y registro de evidencias

- [Diagrama draw.io multipágina con vistas previas y explicaciones](diagramas/README.md).
- [Organización y registro de evidencias fotográficas y de pruebas](fotos/README.md).

**Estado:** diagramas propuestos; no constituyen RTL terminado ni simulación/fotografías de funcionamiento.
''')
append_once(docs/'04-plan-y-trazabilidad.md','## Seguimiento H2 — documentación de arquitectura', '''
## Seguimiento H2 — documentación de arquitectura

- **Preparado (pendiente de revisión humana):** cinco diagramas conceptuales y sus explicaciones, en [diagramas/](diagramas/README.md).
- **Evidencia fotográfica:** organizada por identificación, conexión, simulación, funcionamiento, integración y mediciones. Véase [fotos/README.md](fotos/README.md).
- **No realizado todavía:** validación de `NC`, RTL, testbench, conexión eléctrica y pruebas físicas.
- **Responsables efectivos y revisiones:** completar según commits y evidencias reales, sin atribución automática a los seis integrantes.
''')
append_once(docs/'05-declaracion-uso-ia.md','## Actualización H2 — diagramas editables', '''
## Actualización H2 — diagramas editables

Se utilizó **ChatGPT (OpenAI)** para proponer y redactar la arquitectura del controlador HUB75E, el algoritmo de barrido, una máquina de estados, la temporización conceptual y una organización mínima de framebuffer RGB111. También ayudó a generar **dibujos editables `.drawio` y vistas previas PNG/SVG**, explicaciones Markdown y la estructura documental de evidencias.

Estos artefactos son **propuestas**, no RTL implementado ni resultados de simulación o medición. Los cálculos de refresco son ejemplos hipotéticos explícitos. El equipo debe contrastar la información contra el hardware, justificar los cambios, diseñar y ejecutar por sí mismo las verificaciones y registrar responsables individuales. No se ha confirmado el esquema físico de selección de filas del panel (`NC`).
''')
print('Fase H2 aplicada. Revisar con: git status -sb && git diff --check && git diff --stat')
