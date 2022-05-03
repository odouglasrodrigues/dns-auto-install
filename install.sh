#!/bin/bash

################## FUNCOES NECESSÁRIAS PARA A APLICACAO

function EscolhaOTipoDeInstalacao {
    instalacaoEscolhida=$(dialog --menu "Qual instalação deseja realizar?" 13 48 15 \
        1 "Completa - DNS Reverso + Recursivo" \
        2 "Apenas DNS Reverso" \
        3 "Apenas DNS Recursivo" \
        4 "Sair" --stdout)

    if [ $instalacaoEscolhida = 1 ]; then
        echo "Escolheu 1"
    elif [ $instalacaoEscolhida = 2 ]; then
        echo "Escolheu 2"
    elif [ $instalacaoEscolhida = 3 ]; then
        echo "Escolheu 3"
    elif [ $instalacaoEscolhida = 4 ]; then
        echo "Escolheu 4"
    fi
}

function VerificaInstalacaoDoBind {
    bind9Existe=$(dpkg -l bind9 | grep -i 'ii' | cut -d ' ' -f1)

    if [ $bind9Existe = "ii" ]; then
        dialog --title "Modificar instalacao?" --yesno "O Bind9 já está instalado nesse servidor, deseja prosseguir e modificar a instalacao?" 10 25
        modificarBind=$?
        clear

        if [ $modificarBind = 0 ]; then
            echo "Instalando dependencias necessárias..."
            sudo apt update -y && sudo apt install dialog ipcalc whois
            EscolhaOTipoDeInstalacao

        else
            echo "O Bind não será modificado"
            exit

        fi

    else

        dialog --title "Instalar Bind9?" --yesno "O Bind9 não está instalado, deseja seguir com a instalacao?" 10 25
        continuarInstalacao=$?
        clear

        if [ $continuarInstalacao = 0 ]; then
            echo "Instalando dependencias necessárias..."
            sudo apt update -y && sudo apt install dialog ipcalc whois #bind9 dnsutils
            EscolhaOTipoDeInstalacao

        else
            echo "O Bind não será instalado"
            exit

        fi
    fi

}

function ConsultarBlocosDoASN {
    whois AS$ASN | grep -v :: | grep -i inetnum | cut -d ':' -f 2 | sed 's/ //g' >blocos.txt
}

function VerificarOrigemDoPrefixo {
    origemPrefixo=$(dialog --menu "Deseja informar o prefixo ou o sistema pode criar para todos os prefixos do AS?" 13 58 15 \
        1 "Informar AS" \
        2 "Informar prefixo /24" \
        3 "Informar prefixo menor que /24 (/23, /22 etc...)" \
        4 "Sair" --stdout)

    if [ $origemPrefixo = 1 ]; then
        ASN=$(dialog --inputbox 'Informe o AS que será feito o DNS reverso' 10 25 --stdout)
        ASN=$(echo $ASN | sed 's/as//g' | sed 's/AS//g' | sed 's/As//g' | sed 's/aS//g')
        ConsultarBlocosDoASN
        QuebrarBlocosEm24

    elif [ $origemPrefixo = 2 ]; then
        prefixo24=$(dialog --inputbox 'Informe o prefixo /24 - (Ex: 10.0.0.0/24)' 10 30 --stdout)
        echo $prefixo24 | cut -d '/' -f1 | sed 's/ //g' | sed -r 's/..$//g' >blocos-formatados.txt

    elif [ $origemPrefixo = 3 ]; then
        prefixoMenorQue24=$(dialog --inputbox 'Informe o prefixo - (Ex: 10.0.0.0/23 ou 10.0.0.0/22)' 10 30 --stdout)
        echo $prefixoMenorQue24 >blocos.txt
        QuebrarBlocosEm24

    elif [ $origemPrefixo = 4 ]; then
        echo "Escolheu 4"

    fi
}

function QuebrarBlocosEm24 {
    rm blocos-formatados.txt
    for BLOCO in $(cat blocos.txt); do

        ipcalc $BLOCO 24 | grep -v $BLOCO | grep -i 'network' | cut -d ':' -f2 | cut -d '/' -f1 | sed 's/ //g' | sed -r 's/..$//g' >>blocos-formatados.txt

    done
}

function ModificaOArquivoDeZonas {

    arquivoDeZonas="named.conf.local"

    echo "// Nova modificacao feita pelo instalador TriplePlay Networks" >>$arquivoDeZonas

    for PREFIXO in $(cat blocos-formatados.txt); do

        A=$(echo $PREFIXO | cut -d '.' -f 1)
        B=$(echo $PREFIXO | cut -d '.' -f 2)
        C=$(echo $PREFIXO | cut -d '.' -f 3)

        echo "
zone "'"'"$C.$B.$A.in-addr.arpa"'"'" {
    type master;
    file "'"'"/etc/bind/reverse/$A.$B.$C.rev"'"'";
};" >>$arquivoDeZonas

    done

}

function CriarArquivoDeZona {

    for PREFIXO in $(cat blocos-formatados.txt); do

        A=$(echo $PREFIXO | cut -d '.' -f 1)
        B=$(echo $PREFIXO | cut -d '.' -f 2)
        C=$(echo $PREFIXO | cut -d '.' -f 3)

        echo "
"'$ORIGIN'" .
"'$TTL'" 86400      ; 1 day
$C.$B.$A.in-addr.arpa IN SOA ns1.$dominio. hostmaster.$dominio. (
                    2022050300 ; serial
                    10800      ; refresh (3 hours)
                    3600       ; retry (1 hour)
                    2419200    ; expire (4 weeks)
                    300        ; minimum (5 minutes)
                    )
                NS      ns1.$dominio.
                NS      ns2.$dominio.
 
"'$ORIGIN'" $C.$B.$A.in-addr.arpa.
"'$GENERATE'" 0-255 $ PTR $A-$B-$C-$.$dominio." >$A.$B.$C.rev

    done

}

################ FIM DAS FUNCOES



#VerificarOrigemDoPrefixo
#dominio=$(dialog --inputbox 'Informe seu dominio. Ex: meuprovedor.com.br' 10 30 --stdout)
#ModificaOArquivoDeZonas
#CriarArquivoDeZona

VerificaInstalacaoDoBind

function InstalaDnsRecursivo {
    
}
