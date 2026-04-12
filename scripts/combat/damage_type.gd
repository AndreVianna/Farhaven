class_name DamageType

## Damage type vocabulary -- used by EnduranceCap multipliers and DamageEvents.
## Chapter 1 uses PHYSICAL only; others exist for forward compatibility.
enum Type {
	PHYSICAL,
	FIRE,
	COLD,
	POISON,
	ELECTRIC,
	MAGIC,
}
