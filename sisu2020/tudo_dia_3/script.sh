#!/bin/bash
# Todos os cursos:
curl 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/cursos/alfabeto' --compressed > todos_cursos.json

# Todos os municípios
curl 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/municipios/uf' --compressed > todos_municipios.json

# Todas as instituições
curl 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/instituicoes/uf' --compressed > todos_instituicoes.json

# Baixar ofertas de cada curso
mkdir -p cursos
for i in `jq ".[] | .[] | .co_curso" todos_cursos.json | sort -uh`; do bash -c "curl -sS 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/curso/$i' --compressed > cursos/$i.json"; done

# Baixar modalidades de cada oferta
mkdir -p modalidades
for j in `find cursos/ -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do bash -c "curl 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/$i/modalidades' --compressed -o modalidades/$i.json"; done; done

# Gerar arquivo com todas as notas de corte de todas as modalidades das ofertas de todos os cursos
for j in `find cursos/ -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do jq '.oferta as $oferta | .modalidades[] | {no_curso: $oferta.no_curso, sg_ies: $oferta.sg_ies, no_municipio_campus:$oferta.no_municipio_campus, sg_uf_campus:$oferta.sg_uf_campus, nu_nota_corte: .nu_nota_corte, co_concorrencia: .co_concorrencia, tp_mod_concorrencia: .tp_mod_concorrencia, no_concorrencia: .no_concorrencia}' modalidades/$i.json ; done; done | jq -r 'join("\t")' > todas_notas_corte.tsv
