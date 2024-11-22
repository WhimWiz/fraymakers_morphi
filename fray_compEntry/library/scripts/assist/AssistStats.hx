// Assist stats for Template Assist

// Define some states for our state machine
STATE_IDLE = 0;
STATE_FLUID = 1;
STATE_CAPTURE = 2;
STATE_OUT = 3;


{
	spriteContent: self.getResource().getContent("morphi"),
	initialState: STATE_IDLE,
	stateTransitionMapOverrides: [
		STATE_IDLE => {
			animation: "intro"
		},
		STATE_FLUID => {
			animation: "fluid_air_down"
		},
		STATE_CAPTURE => {
			animation: "captured"
		},
		STATE_OUT => {
			animation: "outro"
		}
	],
	gravity: 0.2,
	aerialFriction: 0,
	friction: 0,
	terminalVelocity: 20,
	assistChargeValue:105
}
