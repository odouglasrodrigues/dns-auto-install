#!/bin/bash

prefixo24=$(dialog --inputbox 'Informe o prefixo /24 - (Ex: 10.0.0.0/24)' 10 30 --stdout)
echo $prefixo24

function validaIPv4 {

    W=$(echo $prefixo24 | cut -d '.' -f 1)
    X=$(echo $prefixo24 | cut -d '.' -f 2)
    Y=$(echo $prefixo24 | cut -d '.' -f 3)
    Z=$(echo $prefixo24 | cut -d '.' -f 4 | cut -d '/' -f 1)
    M=$(echo $prefixo24 | cut -d '/' -f 2)

    echo "W $W "
    echo "X $X"
    echo "Y $Y"
    echo "Z $Z"
    echo "M $M"
    if [ $W -le 255 -a $X -le 255 -a $Y -le 255 -a $Z -le 255 ]; then
        echo "O IP é valido"
    else
        echo "O IP não é válido"
    fi

}

validaIPv4
