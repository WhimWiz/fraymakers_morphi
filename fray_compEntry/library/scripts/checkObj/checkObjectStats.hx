
{
	spriteContent: self.getResource().getContent("morphi"),
	stateTransitionMapOverrides: [
		PState.ACTIVE => {
			animation: "morphiCheckObj"
		}
	],
	gravity: 0,
	friction: 0,
	ghost: true,
	deathBoundsDestroy: false
}
