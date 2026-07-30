<?php

namespace App\Domain\Menu\Enums;

enum ModifierGroupType: string
{
    case Choice = 'choice';
    case AddOn = 'add_on';
    case PreparationInstruction = 'preparation_instruction';
}
