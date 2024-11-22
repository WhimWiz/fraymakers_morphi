// GHOST STATS
// -----------------------------------------------------------------------------------------------------------------------------------------
STATE_IDLE = 0;
STATE_STUNNED = 1;
STATE_DASH = 2;

{
	spriteContent: self.getResource().getContent("morphi"),
	initialState: STATE_STUNNED,
	stateTransitionMapOverrides: [
		STATE_IDLE => {
			animation: "ghost"
		},
		STATE_STUNNED => {
			animation: "ghost_stunned"
		},
		STATE_DASH => {
			animation: "ghost_dash"
		}
	],
	gravity: 0,
	friction: 0,
	groundSpeedCap: 15,
	aerialSpeedCap: 15,
	aerialFriction: 0.1,
	terminalVelocity: 20,
	ghost: true,
	deathBoundsDestroy: false
}
