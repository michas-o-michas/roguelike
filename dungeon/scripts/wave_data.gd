class_name WaveData
extends Resource

## Entradas de mobs desta wave: cada entrada define um tipo e quantidade.
@export var entries: Array[WaveMobEntry] = []

## Delay em segundos após o anúncio "ONDA X/Y" antes de spawnar os mobs.
@export var spawn_delay: float = 1.5

## Multiplicador de HP aplicado a todos os mobs desta wave (1.0 = sem bônus).
@export var hp_multiplier: float = 1.0

## Multiplicador de dano aplicado a todos os mobs desta wave (1.0 = sem bônus).
@export var damage_multiplier: float = 1.0
