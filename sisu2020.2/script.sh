#!/bin/sh

# ###### Rodar uma vez no início do SiSU ######
# Todos os cursos:
curl 'https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta/cursos/alfabeto' --compressed > cursos.json

# Todos os municípios
curl 'https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta/municipios/uf' --compressed > municipios.json

# Todas as instituições
curl 'https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta/instituicoes/uf' --compressed > instituicoes.json

# Baixar informações sobre instituições
mkdir -p instituicoes
for i in `jq -r ".[] | .[] | .co_ies" instituicoes.json | sort -uh`; do echo "instituicoes/$i"; bash -c "curl -# 'https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta/instituicao/$i' --compressed > instituicoes/$i.json"; done

# Baixar informações sobre cursos
mkdir -p cursos
for i in `jq ".[] | .[] | .co_curso" cursos.json | sort -uh`; do bash -c "curl -sS 'https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta/curso/$i' --compressed > cursos/$i.json"; done




###### Rodar diariamente ######
DIA=final
cd /home/paulo/paulosoares.github.io/sisu2020.2

# Baixar notas de corte de cada oferta (rodar esse comando para cada parcial)
for j in `find cursos/ -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do echo $i; done; done | fmt -w300 | tr ' ' ',' | awk -v url="https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta" '{print url "/{" $1 "}/modalidades"}' | xargs -n1 curl -s -Z --compressed --create-dirs -o "$DIA/#1.json"
	
# Consolidar todas as notas de corte
for j in `find cursos/ -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do jq '.oferta as $oferta | .modalidades[] | {no_curso: $oferta.no_curso, sg_ies: $oferta.sg_ies, no_municipio_campus:$oferta.no_municipio_campus, sg_uf_campus:$oferta.sg_uf_campus, nu_nota_corte: .nu_nota_corte, co_concorrencia: .co_concorrencia, tp_mod_concorrencia: .tp_mod_concorrencia, no_concorrencia: .no_concorrencia}' $DIA/$i.json ; done; done | jq -r 'join("\t")' > corte_$DIA.tsv

# Consolidar notas de corte de cursos especificados no arquivo lista
for j in `find cursos/ -type f | grep -f lista`; do for i in `jq -r '.[] | .co_oferta?' $j`; do jq '.oferta as $oferta | .modalidades[] | {co_termo_adesao: $oferta.co_termo_adesao, no_curso: $oferta.no_curso, qt_vagas_sem1: $oferta.qt_vagas_sem1, qt_vagas_sem2: $oferta.qt_vagas_sem2, no_turno: $oferta.no_turno, no_campus: $oferta.no_campus, sg_uf_campus: $oferta.sg_uf_campus, no_ies: $oferta.no_ies, sg_ies: $oferta.sg_ies, no_municipio_campus: $oferta.no_municipio_campus, no_sitio_ies: $oferta.no_sitio_ies, co_concorrencia:.co_concorrencia,  no_concorrencia:.no_concorrencia,  qt_vagas:.qt_vagas,  qt_vagas_concorrencia:.qt_vagas_concorrencia,  nu_nota_corte:.nu_nota_corte,  tp_mod_concorrencia:.tp_mod_concorrencia}' $DIA/$i.json ; done; done | jq -r 'join("\t")' > corte_lista_$DIA.tsv

# Consolidar todas as notas de corte de medicina (ampla e cotas)
for j in `find cursos/37.json -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do jq '.oferta as $oferta | .modalidades[] | {no_curso: $oferta.no_curso, sg_ies: $oferta.sg_ies, no_municipio_campus:$oferta.no_municipio_campus, sg_uf_campus:$oferta.sg_uf_campus, nu_nota_corte: .nu_nota_corte, co_concorrencia: .co_concorrencia, tp_mod_concorrencia: .tp_mod_concorrencia, no_concorrencia: .no_concorrencia}' $DIA/$i.json ; done; done | jq -r 'join("\t")' > corte_medicina_$DIA.tsv

# Gerar notas de corte de ampla concorrência (co_concorrencia == 0):
for i in `jq -r '.[] | .co_oferta?' cursos/37.json`; do jq -c '{universidade:.oferta.sg_ies, cidade:.oferta.no_municipio_campus, uf:.oferta.sg_uf_campus, RD:.oferta.nu_peso_r, CN:.oferta.nu_peso_cn, CH:.oferta.nu_peso_ch, LC:.oferta.nu_peso_l, MT:.oferta.nu_peso_m, vagas:.modalidades[] | select(.co_concorrencia == "0") | .qt_vagas_concorrencia,  corte2020:.modalidades[] | select(.co_concorrencia == "0") | .nu_nota_corte}' $DIA/$i.json; done > bd1$DIA
echo "[" > bd2$DIA; 
paste -sd "," bd1$DIA >> bd2$DIA
echo "]" >> bd2$DIA;
cat bd2$DIA | awk 'NR > 1 { } {printf "%s",$0}' > bd;
rm bd1$DIA bd2$DIA;

#Atualiza o horário
date +"%x às %X ($DIA)" > horario

git add .
git commit -a -m "Atualização"
git push

###### Monitoramento ######
# Monitorar liberação das notas
bash -c 'echo -e "\nAguarde..."; while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' https://sisualuno-api-pcr.apps.mec.gov.br/api/v1/edicao/ativa)" != "200" ]]; do sleep 5; done; echo -e "Dados carregados"'


###### Baixar lista de selecionados ######
mkdir -p selecionados
for j in `find cursos/ -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do echo "selecionados/$i.json"; bash -c "curl -# 'https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta/$i/selecionados' --compressed -o selecionados/$i.json"; done; done

mkdir -p selecionados_csv_mec
while read ies termo; do bash -c "curl -C - -# 'https://sisu.mec.gov.br/static/listagem-alunos-aprovados-portal/listagem-alunos-aprovados-ies-$ies-$termo.csv' -o selecionados_csv_mec/$ies.json --compressed"; done <<< `jq -r 'del(.search_rule) | .[] | {co_ies, co_termo_adesao} | join("\t")' cursos/*.json | sort -u`

###### Gerar lista de selecionados ######
echo -e "no_curso\\tsg_ies\\tno_municipio_campus\\tsg_uf_campus\\tco_inscricao_enem\\tno_inscrito\\tnu_classificacao\\tnu_nota_candidato\\tqt_bonus_perc\\ttp_mod_concorrencia\\tco_mod_concorrencia\\tno_mod_concorrencia\\tco_legenda\\tds_legenda" > selecionados.tsv
for j in `find cursos/ -type f`; do for i in `jq -r 'del(.search_rule) | .[] | .co_oferta' $j`; do jq -r -n --argfile o1 final/$i.json --argfile o2 selecionados/$i.json '$o1.oferta as $o | .selecionados = $o2 | .selecionados | .[] | {no_curso: $o.no_curso, sg_ies: $o.sg_ies, no_municipio_campus: $o.no_municipio_campus, sg_uf_campus: $o.sg_uf_campus, co_inscricao_enem, no_inscrito, nu_classificacao, nu_nota_candidato, qt_bonus_perc, tp_mod_concorrencia, co_mod_concorrencia, no_mod_concorrencia, co_legenda, ds_legenda}' | jq -r 'join("\t")'; done; done >> selecionados.tsv

###### Comparar lista de selecionados JSON com CSV ######

for i in `find selecionados/ -type f`; do jq -r ".[] | .no_inscrito" $i; done > selecionados_json.txt
sort selecionados_json.txt -o selecionados_json_ordenado.txt
rm selecionados_json.txt

for i in `find selecionados_csv_mec/* -type f`; do csvjson -d ';' -K 1 -H $i | jq -r ".[] | .l"; done > selecionados_csv_mec.txt
sort selecionados_csv_mec.txt -o selecionados_csv_mec_ordenado.txt
rm selecionados_csv_mec.txt

diff selecionados_json_ordenado.txt selecionados_csv_mec_ordenado.txt


# Baixar lista de espera
rm -rf lista_espera
for j in `find cursos/ -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do echo $i; done; done | fmt -w300 | tr ' ' ',' | awk -v url="https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta" '{print url "/{" $1 "}/selecionados-lista-espera"}' | xargs -n1 curl -s -Z --compressed --create-dirs -o 'lista_espera/#1.json'

#Minha posição na UFRJ
jq -r -c ".[] | .no_inscrito" lista_espera/148844.json | nl | grep -i "Paulo Augusto"


#Pega a atualização da lista de espera assim que ela estiver disponível
bash -c 'echo -e "\nAguarde..."; while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta/148844/selecionados-lista-espera)" != "200" ]]; do sleep 5; done; notify-send "Dados carregados"'; for j in `find cursos/ -type f`; do for i in `jq -r '.[] | .co_oferta?' $j`; do echo $i; done; done | fmt -w300 | tr ' ' ',' | awk -v url="https://sisu-api-pcr.apps.mec.gov.br/api/v1/oferta" '{print url "/{" $1 "}/selecionados-lista-espera"}' | xargs -n1 curl -s -Z --compressed --create-dirs -o 'lista_espera/#1.json'
