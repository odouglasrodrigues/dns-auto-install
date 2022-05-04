#!/bin/bash

sudo apt update -y && sudo apt install dialog

################## FUNCOES NECESSÁRIAS PARA A APLICACAO

function SalvaPermissoesEReiniciaBind {

    chown bind. /etc/bind/ -R
    service bind9 restart

}

function MoveOsArquivos {

    mv named.conf.options /etc/bind/named.conf.options

    rm *.txt
    rm *.acl

}

function MontaAclDeAutorizados {

    if [ $escolhaListadeAcesso = 1 ]; then
        VerificaSeTemV6
        echo "
acl autorizados {
    127.0.0.1;
    ::1;
    192.168.0.0/16;
    172.16.0.0/12;
    100.64.0.0/10;
    10.0.0.0/8;
    df00::/8;
    2001:db8::/32;
    fe80::/64;" >acl-autorizados.acl

        for PREFIXO in $(cat blocos.txt); do
            echo "    $PREFIXO;" >>acl-autorizados.acl
        done
        for PREFIXO in $(cat blocos-v6.txt); do
            echo "    $PREFIXO;" >>acl-autorizados.acl
        done
        echo "};" >>acl-autorizados.acl

    elif
        [ $escolhaListadeAcesso = 2 ]
    then
        echo "
acl autorizados {
        127.0.0.1;
        ::1;
        192.168.0.0/16;
        172.16.0.0/12;
        100.64.0.0/10;
        10.0.0.0/8;
        df00::/8;
        2001:db8::/32;
        fe80::/64;
}; 
" >acl-autorizados.acl

    elif [ $escolhaListadeAcesso = 3 ]; then
        VerificaSeTemV6
        echo "
acl autorizados {
    127.0.0.1;
    ::1;" >acl-autorizados.acl

        for PREFIXO in $(cat blocos.txt); do
            echo "    $PREFIXO;" >>acl-autorizados.acl
        done
        for PREFIXO in $(cat blocos-v6.txt); do
            echo "    $PREFIXO;" >>acl-autorizados.acl
        done
        echo "};" >>acl-autorizados.acl

    else
        clear
        echo "Nenhuma opcao escolhida - Instalacao encerrada"
        exit
    fi

}

function ModificaOArquivoDeZonas {

    arquivoDeZonas="/etc/bind/named.conf.local"

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

    if [ -d /etc/bind/reverse/ ]; then
        echo "Diretorio de zonas reversas OK."
    else
        mkdir /etc/bind/reverse/
    fi

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
"'$GENERATE'" 0-255 $ PTR $A-$B-$C-$.$dominio." >/etc/bind/reverse/$A.$B.$C.rev

    done

}

function InstalaDnsReverso {
    ModificaOArquivoDeZonas
    CriarArquivoDeZona
}

function InstalaDnsRecursivo {

    escolhaListadeAcesso=$(dialog --radiolist "DNS Recursivo - Quais IPs você deseja permitir a consulta?" 12 55 3 \
        "1" "Todos os privados + IPs ja informados" ON \
        "2" "Apenas privados" OFF \
        "3" "Apenas IPs já informados" OFF --stdout)

    MontaAclDeAutorizados

    aclAutorizados=$(cat acl-autorizados.acl)

    echo "
// Configuracoes feitas automaticamente pelo instalador automatico da
// TriplePlay Networks

$aclAutorizados 
 
options {
    directory "'"'"/var/cache/bind"'"'";

    dnssec-validation auto;
 
    auth-nxdomain no;

    listen-on { any; };
    listen-on-v6 { any; };
 
    minimal-responses yes;
 
    max-ncache-ttl 30;

    allow-recursion { autorizados; };
 
    allow-query-cache { autorizados; };

    allow-query { any; };
 
    version "'"'"TriplePlay Networks - DNS Server"'"'";
 
};" >named.conf.options
}

function ConsultarBlocosDoASN {
    whois AS$ASN | grep -v :: | grep -i inetnum | cut -d ':' -f 2 | sed 's/ //g' >blocos.txt
    whois AS$ASN | grep :: | grep -i inetnum | sed 's/ //g' | sed 's/inetnum://g' >blocos-v6.txt
}

function VerificaSeTemV6 {
    prefixosV6=$(cat blocos-v6.txt)

    if [ -z $prefixosV6 ]; then

        dialog --title "Sem IPv6 informado" --yesno "Nao foi identificado nenhum IPv6 nos prefixos informados, deseja informar um prefixo IPv6 para a lista de acesso?" 10 40
        adicionarv6=$?
        clear

        if [ $adicionarv6 = 0 ]; then
            blocoIpv6=$(dialog --inputbox 'Informe o seu prefixo IPv6 - (Ex: 2001:db8::/32 ou 2001:db8::/40)' 10 40 --stdout)
            echo $blocoIpv6 >blocos-v6.txt

        else
            echo >blocos-v6.txt

        fi

    else
        echo "Prefixo V6 encontrado"
    fi
}

function QuebrarBlocosEm24 {
    for BLOCO in $(cat blocos.txt); do

        ipcalc $BLOCO 24 | grep -v $BLOCO | grep -i 'network' | cut -d ':' -f2 | cut -d '/' -f1 | sed 's/ //g' | sed -r 's/..$//g' >>blocos-formatados.txt

    done
}

function VerificarOrigemDoPrefixo {
    origemPrefixo=$(dialog --menu "Deseja informar o prefixo ou o sistema pode criar para todos os prefixos do AS?" 13 58 15 \
        1 "Informar AS" \
        2 "Informar prefixo /24" \
        3 "Informar prefixo menor que /24 (/23, /22 etc...)" \
        4 "Sair" --stdout)

    if [ $origemPrefixo = 1 ]; then
        ASN=$(dialog --inputbox 'Informe o AS que sera feito o DNS reverso' 10 25 --stdout)
        ASN=$(echo $ASN | sed 's/as//g' | sed 's/AS//g' | sed 's/As//g' | sed 's/aS//g')
        ConsultarBlocosDoASN
        QuebrarBlocosEm24

    elif [ $origemPrefixo = 2 ]; then
        prefixo24=$(dialog --inputbox 'Informe o prefixo /24 - (Ex: 10.0.0.0/24)' 10 30 --stdout)
        echo $prefixo24 >blocos.txt
        echo >blocos-v6.txt
        echo $prefixo24 | cut -d '/' -f1 | sed 's/ //g' | sed -r 's/..$//g' >blocos-formatados.txt

    elif [ $origemPrefixo = 3 ]; then
        prefixoMenorQue24=$(dialog --inputbox 'Informe o prefixo - (Ex: 10.0.0.0/23 ou 10.0.0.0/22)' 10 30 --stdout)
        echo $prefixoMenorQue24 >blocos.txt
        echo >blocos-v6.txt
        QuebrarBlocosEm24

    elif [ $origemPrefixo = 4 ]; then
        echo "Escolheu 4"

    fi
}

function InstalaBind9 {

    echo "Instalando Bind9..."
    sudo apt install bind9 dnsutils -y
    sleep 5
    echo "Configurando servidor..."
    sudo echo "nameserver 127.0.0.1" >/etc/resolv.conf
    sudo echo "nameserver ::1" >>/etc/resolv.conf
    sleep 3

    echo "
// Configuracoes feitas automaticamente pelo instalador automatico da
// TriplePlay Networks

acl autorizados {
        127.0.0.1;
        ::1;
}; 
 
options {
    directory "'"'"/var/cache/bind"'"'";

    dnssec-validation auto;
 
    auth-nxdomain no;

    listen-on { any; };
    listen-on-v6 { any; };
 
    minimal-responses yes;
 
    max-ncache-ttl 30;

    allow-recursion { autorizados; };
 
    allow-query-cache { autorizados; };

    allow-query { any; };
 
    version "'"'"TriplePlay Networks - DNS Server"'"'";
 
};" >named.conf.options

    echo "Bind9 Instalado com sucesso!"

}

function EscolhaOTipoDeInstalacao {
    instalacaoEscolhida=$(dialog --menu "Qual instalação deseja realizar?" 13 48 15 \
        1 "Completa - DNS Reverso + Recursivo" \
        2 "Apenas DNS Reverso" \
        3 "Apenas DNS Recursivo" \
        4 "Sair" --stdout)

    if [ $instalacaoEscolhida = 1 ]; then
        InstalaBind9
        VerificarOrigemDoPrefixo
        dominio=$(dialog --inputbox 'Informe seu dominio. Ex: meuprovedor.com.br' 10 30 --stdout)
        InstalaDnsRecursivo
        InstalaDnsReverso
    elif [ $instalacaoEscolhida = 2 ]; then
        InstalaBind9
        VerificarOrigemDoPrefixo
        dominio=$(dialog --inputbox 'Informe seu dominio. Ex: meuprovedor.com.br' 10 30 --stdout)
        InstalaDnsReverso
    elif [ $instalacaoEscolhida = 3 ]; then
        InstalaBind9
        VerificarOrigemDoPrefixo
        InstalaDnsRecursivo
    elif [ $instalacaoEscolhida = 4 ]; then
        exit
        clear
    fi
}

function VerificaInstalacaoDoBind {
    bind9Existe=$(dpkg -l bind9 | grep -i 'ii' | cut -d ' ' -f1)

    if [ $bind9Existe = "ii" ]; then
        dialog --title "Modificar instalacao?" --yesno "O Bind9 ja esta instalado nesse servidor, deseja prosseguir e modificar a instalacao?" 10 25
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

        dialog --title "Instalar Bind9?" --yesno "O Bind9 nao esta instalado, deseja seguir com a instalacao?" 10 25
        continuarInstalacao=$?
        clear

        if [ $continuarInstalacao = 0 ]; then
            echo "Instalando dependencias necessarias..."
            sudo apt update -y && sudo apt install dialog ipcalc whois #bind9 dnsutils
            EscolhaOTipoDeInstalacao

        else
            echo "O Bind nao sera instalado"
            exit

        fi
    fi

}

################ FIM DAS FUNCOES

VerificaInstalacaoDoBind
MoveOsArquivos
SalvaPermissoesEReiniciaBind
