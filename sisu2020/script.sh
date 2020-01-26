#!/bin/sh

###### Rodar uma vez no início do SiSU ######
# Todos os cursos:
curl 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/cursos/alfabeto' --compressed > cursos.json

# Todos os municípios
curl 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/municipios/uf' --compressed > municipios.json

# Todas as instituições
curl 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/instituicoes/uf' --compressed > instituicoes.json

# Baixar informações sobre instituições
mkdir -p instituicoes
for i in `jq -r ".[] | .[] | .co_ies" instituicoes.json | sort -uh`; do echo "instituicoes/$i"; bash -c "curl -# 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/instituicao/3223/$i' --compressed > instituicoes/$i.json"; done

# Baixar informações sobre cursos
mkdir -p cursos
for i in `jq ".[] | .[] | .co_curso" cursos.json | sort -uh`; do bash -c "curl -sS 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/curso/$i' --compressed > cursos/$i.json"; done




###### Rodar diariamente ######
DIA=dia5
# Baixar notas de corte de cada oferta (rodar esse comando para cada parcial)
mkdir -p $DIA
for j in `find cursos/ -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do echo "$DIA/$i.json"; bash -c "curl -# 'https://sisu-api.apps.mec.gov.br/api/v1/oferta/$i/modalidades' --compressed -o $DIA/$i.json"; done; done
	
# Consolidar todas as notas de corte
for j in `find cursos/ -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do jq '.oferta as $oferta | .modalidades[] | {no_curso: $oferta.no_curso, sg_ies: $oferta.sg_ies, no_municipio_campus:$oferta.no_municipio_campus, sg_uf_campus:$oferta.sg_uf_campus, nu_nota_corte: .nu_nota_corte, co_concorrencia: .co_concorrencia, tp_mod_concorrencia: .tp_mod_concorrencia, no_concorrencia: .no_concorrencia}' $DIA/$i.json ; done; done | jq -r 'join("\t")' > corte_$DIA.tsv

# Consolidar notas de corte de cursos especificados no arquivo lista
for j in `find cursos/ -type f | grep -f lista`; do for i in `jq -r '.[] | .co_oferta?' $j`; do jq '.oferta as $oferta | .modalidades[] | {co_termo_adesao: $oferta.co_termo_adesao, no_curso: $oferta.no_curso, qt_vagas_sem1: $oferta.qt_vagas_sem1, qt_vagas_sem2: $oferta.qt_vagas_sem2, no_turno: $oferta.no_turno, no_campus: $oferta.no_campus, sg_uf_campus: $oferta.sg_uf_campus, no_ies: $oferta.no_ies, sg_ies: $oferta.sg_ies, no_municipio_campus: $oferta.no_municipio_campus, no_sitio_ies: $oferta.no_sitio_ies, co_concorrencia:.co_concorrencia,  no_concorrencia:.no_concorrencia,  qt_vagas:.qt_vagas,  qt_vagas_concorrencia:.qt_vagas_concorrencia,  nu_nota_corte:.nu_nota_corte,  tp_mod_concorrencia:.tp_mod_concorrencia}' $DIA/$i.json ; done; done | jq -r 'join("\t")' > corte_lista_$DIA.tsv

# Consolidar todas as notas de corte de medicina (ampla e cotas)
for j in `find cursos/37.json -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do jq '.oferta as $oferta | .modalidades[] | {no_curso: $oferta.no_curso, sg_ies: $oferta.sg_ies, no_municipio_campus:$oferta.no_municipio_campus, sg_uf_campus:$oferta.sg_uf_campus, nu_nota_corte: .nu_nota_corte, co_concorrencia: .co_concorrencia, tp_mod_concorrencia: .tp_mod_concorrencia, no_concorrencia: .no_concorrencia}' $DIA/$i.json ; done; done | jq -r 'join("\t")' > corte_medicina_$DIA.tsv

# Gerar notas de corte de ampla concorrência (co_concorrencia == 0):
for i in `jq -r '.[] | .co_oferta?' cursos/37.json`; do jq -c '{universidade:.oferta.sg_ies, cidade:.oferta.no_municipio_campus, uf:.oferta.sg_uf_campus, RD:.oferta.nu_peso_r, CN:.oferta.nu_peso_cn, CH:.oferta.nu_peso_ch, LC:.oferta.nu_peso_l, MT:.oferta.nu_peso_m, vagas:.modalidades[] | select(.co_concorrencia == "0") | .qt_vagas_concorrencia,  corte2020:.modalidades[] | select(.co_concorrencia == "0") | .nu_nota_corte}' $DIA/$i.json ; done | jq -r 'join("\t")'




###### Monitoramento ######
# Monitorar liberação das notas
bash -c 'echo -e "\nAguarde..."; while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' https://sisualuno-api.apps.mec.gov.br/api/v1/oferta/116974/modalidades)" != "200" ]]; do sleep 5; done; echo -e "Dados carregados"'