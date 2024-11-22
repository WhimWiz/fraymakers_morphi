// MORPHI SCRIPT
// ---------------------------------------------------------------------------------------------------------------------------------------
STATE_IDLE = 0;
STATE_FLUID = 1;
STATE_CAPTURE = 2;
STATE_OUT = 3;

var morphiCheck:Projectile = null;
var owner:Character = null;
var morphStarted = false;
var morphSubject:Character = null;
var morphClone:Vfx = null;
var morphShader:RgbaColorShader = new RgbaColorShader();
var plyrGhost:Projectile = null;
var plyrGhostSprite:Vfx = null;
var ghostShader:RgbaColorShader = new RgbaColorShader();
var crawlSound:AudioClip = null;
var hitEventData:GameObjectEvent = null;
var hitSpd = 0;
var outroForce = 12;
var outroDirect = 0;
var nameExt:String = "";
var hoodieVFX:Vfx = null;

var camWallBuffer = 10;

var cpuState = 0;
var CPU_STATE_IDLE = 0;
var CPU_STATE_RUN = 1;
var CPU_STATE_JUMP = 2;
var CPU_STATE_FALL = 3;
var CPU_STATE_ATTACK = 4;
var CPU_STATE_HURT = 5;
var CPU_STATE_LEDGE = 6;
var CPU_STATE_GRABBED = 7;
var cpuActivate = false;
var cpuHitstunActive = false;
var cpuAerialMomentum = 0;
var cpuHitstunTimer = null;
var cpuAerialTarget = 0;
var cpuGrabbedBy:Character = null;
var cpuGroundPos = [0, 0];
var cpuArrowSprite:Sprite = null;
var cpuPercentSprite:Sprite = null;
var cpuArrowShader:RgbaColorShader = null;

function initialize(){
	owner = self.getOwner();
	if (self.getOwner().isFacingLeft()) {
		self.faceLeft();
	}
	var x = owner.getX();
	owner.move(70);
	Common.repositionToEntityEcb(self.getOwner(), 0, 0);
	Common.startFadeIn();
	owner.setX(x);

	if(self.getCostumeIndex() == 20){
		nameExt = "sketch_";
		self.playAnimation(nameExt + "intro");
		self.setCostumeIndex(0);
	}
	
	morphShader.color = 0xebccef;
    morphShader.redMultiplier=1/3;
    morphShader.greenMultiplier=1/2;
    morphShader.blueMultiplier=1;

    ghostShader.color = 0x007297;
    ghostShader.redMultiplier=1/3;
    ghostShader.greenMultiplier=1/2;
    ghostShader.blueMultiplier=1;

	self.addEventListener(GameObjectEvent.HIT_DEALT, onHit, {persistent: true});
	self.addEventListener(GameObjectEvent.HITBOX_CONNECTED, beforeHit, {persistent: true});

	if(!checkForMorphis()){
		morphiCheck = match.createProjectile(self.getResource().getContent("morphiCheck"), null);
	}
	else{
		self.getOwner().setAssistCharge(1);
		self.destroy();
	}

	Engine.log("start!");

	self.exports = {
		updateMorphiDamage: function(percent, foe:Projectile){
			cpuPercentSprite.currentFrame += percent;
			outroDirect = (foe.getX() < self.getX() ? 1 : -1);
			if(cpuPercentSprite.currentFrame == cpuPercentSprite.totalFrames){
				morphOnKO();
				return true;
			}
			else{
				return false;
			}
		}
	}
}

function update(){
	updateScale();
	if (self.inState(STATE_IDLE)) {
		
	}
	else if (self.inState(STATE_FLUID)) {
		if(self.getAnimation() == nameExt + "fluid"){
			self.setXSpeed(4);

			if(!self.isOnFloor()){
				crawlSound.stop();
				if(self.getYSpeed() > -1){
					self.playAnimation(nameExt + "fluid_air_down");
				}
				else{
					self.playAnimation(nameExt + "fluid_air_up");
				}
				return;
			}

			if(checkForPlyrsAbove()){
				self.unattachFromFloor();
				if(self.getViewRootContainer().scaleX == 1){
					self.getViewRootContainer().scaleX = 0.6;
					self.getViewRootContainer().scaleY = 1.3;
				}
				AudioClip.play(self.getResource().getContent("jump"));
				self.setYVelocity(-6);
			}
		}
		else {
			if(self.isOnFloor()){
				self.getViewRootContainer().scaleX = 1.8;
				self.getViewRootContainer().scaleY = 0.4;
				crawlSound = AudioClip.play(self.getResource().getContent("crawl"), {loop: true});
				AudioClip.play(self.getResource().getContent("land"));
				self.playAnimation(nameExt + "fluid");
				return;
			}

			if(self.getYSpeed() > -1 && self.getAnimation() != nameExt + "fluid_air_down"){
				self.playAnimation(nameExt + "fluid_air_down");
			}
			else if(self.getYSpeed() <= -1 && self.getAnimation() != nameExt + "fluid_air_up"){
				self.playAnimation(nameExt + "fluid_air_up");
			}
		}
	}
	else if(self.inState(STATE_CAPTURE)){
		morphCPUupdate();
		morphReturnInBounds();
		self.setX(morphSubject.getX());
		self.setY(morphSubject.getY());
	}
}

function createHoodie(){
	hoodieVFX = match.createVfx(new VfxStats({spriteContent: self.getResource().getContent("morphi"), animation: nameExt + "hoodie", 
	x: self.getX(), y: self.getY(), layer: VfxLayer.CHARACTERS_BACK}), null);
	if(self.isFacingLeft()){
		hoodieVFX.faceLeft();
	}
	if(!self.isOnFloor()){
		hoodieVFX.playAnimation(nameExt + "hoodie_fall");
	}
	hoodieVFX.addShader(self.getCostumeShader());
}

function onJump(){
	self.toState(STATE_FLUID, nameExt + "fluid_air_down");
	camera.addTarget(self);
	self.unattachFromFloor();
	self.setX(self.getX() + 58 * (self.isFacingLeft() ? -1 : 1));
	self.setY(self.getY() + -82);
	self.setYSpeed(-2.2);
	self.setXSpeed(2.6);
}

function beforeHit(event:GameObjectEvent){
	if(event.data.foe.getType() == EntityType.CHARACTER){
		event.data.hitboxStats.hitstopOffset = 50;
		event.data.hitboxStats.hitSoundOverride = self.getResource().getContent("morphimpact");
	}
}

function onHit(event:GameObjectEvent){
	if(event.data.foe.getType() == EntityType.CHARACTER && event.data.foe.getHitstop() > 0){
		hitEventData = event;
		morphSubject = hitEventData.data.foe;
		morphSubject.applyGlobalBodyStatus(BodyStatus.INTANGIBLE, 55);
		self.removeEventListener(GameObjectEvent.HIT_DEALT, onHit);
		self.removeEventListener(GameObjectEvent.HITBOX_CONNECTED, beforeHit);
		if(self.getAnimation() == nameExt + "fluid"){
			crawlSound.stop();
		}
		self.setX(morphSubject.getX());
		self.setY(morphSubject.getY());
		hitSpd = self.getXVelocity();
		self.toState(STATE_CAPTURE, nameExt + "captured");
		self.resetMomentum();
	}
}

function createMorph(){
	morphSubject.addShader(morphShader);
	morphSubject.getDamageCounterRenderSprite().addShader(morphShader);
	AudioClip.play(self.getResource().getContent("laugh"), {volume: 8});

	// GHOST OBJECT
	plyrGhost = match.createProjectile(self.getResource().getContent("playerGhost"), null);
	plyrGhost.setX(morphSubject.getX());
	plyrGhost.setY(morphSubject.getY());
	if(hitSpd == 0){
		plyrGhost.setXVelocity(8 * (self.isFacingLeft() ? -1 : 1));
	}
	else{
		plyrGhost.setXVelocity(hitSpd * 2);
	}
	plyrGhost.sendBehind(self);
	camera.addTarget(plyrGhost);

	// GHOST SPRITE
	plyrGhostSprite = match.createVfx(new VfxStats({spriteContent: morphSubject.getPlayerConfig().character.namespace + "::" + morphSubject.getPlayerConfig().character.resourceId + "." + morphSubject.getPlayerConfig().character.contentId, animation: "fall_loop", loop: true}), null);
	plyrGhostSprite.addShader(morphSubject.getCostumeShader());
	plyrGhostSprite.addShader(ghostShader);
	plyrGhostSprite.getSprite().alpha = 0.6;
	plyrGhostSprite.getSprite().scaleX = morphSubject.getCharacterStat("baseScaleX");
	plyrGhostSprite.getSprite().scaleY = morphSubject.getCharacterStat("baseScaleY");
	plyrGhost.getTopLayer().addChild(plyrGhostSprite.getSprite());

	plyrGhost.exports.setControlPlayer(morphSubject, plyrGhostSprite, self);
}

function checkForPlyrsAbove(): Boolean{
	var plyrs:Array<Character> = self.getOwner().getFoes();
	for(i in 0...plyrs.length){
		if(Math.abs(self.getX() - plyrs[i].getX()) < 200 && plyrs[i].getY() < self.getY() + -35){
			return true;
		}
	}
	return false;
}


function updateScale() {
    var scaleX = self.getViewRootContainer().scaleX;
    var scaleY = self.getViewRootContainer().scaleY;

    // Update scaleX
    if (scaleX != 1) {
        if (scaleX > 1) {
            self.getViewRootContainer().scaleX = Math.max(1, scaleX - 0.035);
        } else {
            self.getViewRootContainer().scaleX = Math.min(1, scaleX + 0.035);
        }
    }

    // Update scaleY
    if (scaleY != 1) {
        if (scaleY > 1) {
            self.getViewRootContainer().scaleY = Math.max(1, scaleY - 0.035);
        }
        else {
            self.getViewRootContainer().scaleY = Math.min(1, scaleY + 0.035);
        }
    }
}

function onTeardown(){
	if(self.getAnimation() != nameExt + "intro"){
		camera.deleteTarget(self);
	}
	if(morphiCheck != null){
		morphiCheck.destroy();
	}
}

// ___________________________________________________________________________________________________________________

//                                               v CPU LOGIC v
// ___________________________________________________________________________________________________________________


function morphCPUupdate(){
	var target = plyrGhost;
	if(cpuActivate == true){
		if(cpuState != CPU_STATE_ATTACK && cpuState != CPU_STATE_LEDGE){
			if(target.getX() > morphSubject.getX() && morphSubject.isOnFloor()){
				morphSubject.faceLeft();
			}
			else if(morphSubject.isOnFloor()){
				morphSubject.faceRight();
			}
		}
	if(cpuState == CPU_STATE_IDLE){
		if(morphSubject.getAnimation() != "stand"){
			morphSubject.playAnimation("stand");
		}
		if(morphSubject.getX() < target.getX() + -60 || morphSubject.getX() > target.getX() + 60){
			var runChance = Random.getInt(0, 15);
			if(runChance == 1){
				cpuState = CPU_STATE_RUN;
			}
		}
		if(morphSubject.isOnFloor() == false){
			cpuState = CPU_STATE_FALL;
		}
	}
	else if(cpuState == CPU_STATE_RUN){
		if(morphSubject.getAnimation() != "dash" && morphSubject.getAnimation() != "run"){
			morphSubject.playAnimation("dash");
		}
		else if(morphSubject.getAnimation() == "dash"){
			morphSubject.setXSpeed(morphSubject.getCharacterStat("dashSpeed"));
			if(morphSubject.finalFramePlayed()){
				morphSubject.playAnimation("run");
			}
		}
		else if(morphSubject.getAnimation() == "run"){
			morphSubject.setXSpeed(morphSubject.getCharacterStat("runSpeedCap"));
		}

		if(morphSubject.getX() < target.getX() + 60 && morphSubject.getX() > target.getX() + -60){
			cpuState = CPU_STATE_IDLE;
			return;
		}
		if(!morphSubject.isOnFloor()){
			cpuState = CPU_STATE_FALL;
		}
	}
	else if(cpuState == CPU_STATE_JUMP){
		if(morphSubject.getAnimation() != "jump_in" && morphSubject.getAnimation() != "jump_loop"){
			morphSubject.setYSpeed(-morphSubject.getCharacterStat("jumpSpeed"));
			morphSubject.playAnimation("jump_in");
		}
		else if(morphSubject.getAnimation() == "jump_in"){
			if(morphSubject.finalFramePlayed()){
				morphSubject.playAnimation("jump_loop");
			}
		}
		else if(morphSubject.getAnimation() == "jump_loop"){
			if(morphSubject.getYSpeed() >= 0){
				cpuState = CPU_STATE_FALL;
			}
		}
	}
	else if(cpuState == CPU_STATE_FALL){
		if(morphSubject.getAnimation() != "fall_loop"){
			morphSubject.playAnimation("fall_loop");
		}
		if(morphSubject.isOnFloor()){
			cpuState = CPU_STATE_IDLE;
		}
	}
	else if(cpuState == CPU_STATE_ATTACK){
		if(morphSubject.finalFramePlayed()){
			cpuState = CPU_STATE_IDLE;
		}
	}
	else if(cpuState == CPU_STATE_HURT){
		if(morphSubject.getAnimation() != "hurt_medium"){
			morphSubject.playAnimation("hurt_medium");
		}
		if(cpuHitstunActive == false){
			cpuState = CPU_STATE_FALL;
			cpuAerialMomentum = morphSubject.getXVelocity();
		}
	}
	else if(cpuState == CPU_STATE_LEDGE){
		if(morphSubject.inState(CState.LEDGE_LOOP)){
			if(morphSubject.hasAnimation("ledge_climb_in")){
				morphSubject.toState(CState.LEDGE_CLIMB_IN);
			}
			else{
				morphSubject.toState(CState.LEDGE_CLIMB);
			}
		}
		else if(morphSubject.inState(CState.ledge)){
			morphSubject.updateAnimationStats({nextState: CState.STAND});
		}

		if(!morphSubject.inStateGroup(CStateGroup.LEDGE) && !morphSubject.inStateGroup(CStateGroup.LEDGE_CLIMB)){
			cpuState = CPU_STATE_IDLE;
		}
	}
	else if(cpuState == CPU_STATE_GRABBED){
		if(cpuGrabbedBy.getGrabbedFoe() == null){
			cpuState = CPU_STATE_IDLE;
		}
	}

	if(cpuHitstunActive == false && cpuState != CPU_STATE_LEDGE){

		if(morphSubject.getX() < target.getX() + 180 && morphSubject.getX() > target.getX() + -180 && cpuState != CPU_STATE_ATTACK || morphSubject.getY() > cpuGroundPos[1] + 30 && !morphSubject.isOnFloor() && cpuState != CPU_STATE_ATTACK){
			var jumpChance = Random.getInt(0, 20);
			if(jumpChance == 1){
				if(self.isOnFloor()){
					cpuAerialTarget = -morphSubject.getX() / 1.2;
				}
				cpuState = CPU_STATE_JUMP;
			}
		}
		else if(morphSubject.getY() + 10 > target.getY() && morphSubject.isOnFloor() && morphSubject.getCurrentFloor().getStructureStat("dropThrough")){
			var dropChance = Random.getInt(0, 25);
			if(dropChance == 1){
				morphSubject.unattachFromFloor();
				morphSubject.setY(morphSubject.getY() + 8);
			}
		}	

		if(morphSubject.isOnFloor()){
			cpuGroundPos[0] = self.getX();
			cpuGroundPos[1] = self.getY();
			cpuAerialMomentum = 0;
			if(cpuState != CPU_STATE_ATTACK){
				if(morphSubject.getX() < target.getX() + 90 && morphSubject.getX() > target.getX() + -90 && cpuState == CPU_STATE_IDLE){
					var attackChance = Random.getInt(0, 35);
					if(attackChance == 1){
						cpuState = CPU_STATE_ATTACK;
						morphSubject.playAnimation(Random.getChoice(["tilt_forward", "tilt_up", "tilt_down", "dash_attack"]));
					}
				}
			}
		}
		else
		{
			if(morphSubject.getX() < target.getX() + 90 && morphSubject.getX() > target.getX() + -90){
				var attackChance = Random.getInt(0, 35);
				if(attackChance == 1){
					cpuState = CPU_STATE_ATTACK;
					morphSubject.playAnimation(Random.getChoice(["aerial_neutral", "aerial_forward", "aerial_down", "aerial_up", "aerial_back"]));
				}
			}

			if(morphSubject.getX() <= cpuAerialTarget){
				cpuAerialMomentum = morphSubject.getXVelocity() + 1;
				if(cpuAerialMomentum >= morphSubject.getCharacterStat("aerialSpeedCap")){
					cpuAerialMomentum = morphSubject.getCharacterStat("aerialSpeedCap");
				}
			}
			else{
				cpuAerialMomentum = morphSubject.getXVelocity() + -1;
				if(cpuAerialMomentum <= -morphSubject.getCharacterStat("aerialSpeedCap")){
					cpuAerialMomentum = -morphSubject.getCharacterStat("aerialSpeedCap");
				}
			}
			morphSubject.setXVelocity(cpuAerialMomentum);
		}
	}
	}
}

function morphStartCPU(){
	cpuActivate = true;

	cpuArrowSprite = Sprite.create(self.getResource().getContent("morphi"));
	stage.getForegroundEffectsContainer().addChild(cpuArrowSprite);
	cpuArrowSprite.currentAnimation = "arrow";
	cpuArrowShader = new RgbaColorShader();
	cpuArrowShader.color = morphSubject.getPortColor();// - 11000000;
    cpuArrowShader.redMultiplier=1/3;
    cpuArrowShader.greenMultiplier=1/2;
    cpuArrowShader.blueMultiplier=1;
	cpuArrowSprite.addShader(cpuArrowShader);

	cpuPercentSprite = Sprite.create(self.getResource().getContent("morphi"));
	stage.getForegroundEffectsContainer().addChild(cpuPercentSprite);
	cpuPercentSprite.currentAnimation = "percent";

	match.addEventListener(MatchEvent.TICK_END, morphTickEnd, {persistent: true});
	match.addEventListener(MatchEvent.TICK_START, morphTickStart, {persistent: true});
	morphSubject.addEventListener(GameObjectEvent.HIT_RECEIVED, morphOnHit, {persistent: true});
	morphSubject.addEventListener(CharacterEvent.LEDGE_GRAB, morphOnLedgeGrab, {persistent: true});
	morphSubject.addEventListener(GameObjectEvent.GRAB_RECEIVED, morphGrabbed, {persistent: true});
}

function morphTickStart(){
	morphSubject.updateAnimationStats({interruptible: false, allowMovement: false, leaveGroundCancel: false, endType:AnimationEndType.NONE, slideOff: false});
}

function morphTickEnd(){
	if(cpuActivate && morphSubject.getState() != CState.KO && !morphSubject.inStateGroup(CStateGroup.LEDGE) && !morphSubject.inStateGroup(CStateGroup.LEDGE_CLIMB) && cpuState != CPU_STATE_GRABBED){
		morphSubject.setState(CState.EMOTE);
	}
	if(cpuPercentSprite != null){
		cpuArrowSprite.x = morphSubject.getX();
		cpuArrowSprite.y = morphSubject.getY();
		cpuPercentSprite.x = morphSubject.getX() - 7;
		cpuPercentSprite.y = morphSubject.getY();
	}
}

function morphGrabbed(event:GameObjectEvent){
	cpuState = CPU_STATE_GRABBED;
	cpuGrabbedBy = event.data.foe;
}

function morphOnLedgeGrab(){
	cpuState = CPU_STATE_LEDGE;
}

function morphOnHit(event:GameObjectEvent){
	if(self.getState() == STATE_OUT || !event.data.hitboxStats.flinch){
		return;
	}

	if(cpuPercentSprite != null){
		cpuPercentSprite.currentFrame += event.data.hitboxStats.damage;
	}
	
	cpuHitstunActive = true;
	cpuAerialMomentum = 0;
	cpuState = CPU_STATE_HURT;
	if(cpuHitstunTimer != null){
		morphSubject.removeTimer(cpuHitstunTimer);
	}
	cpuHitstunTimer = morphSubject.addTimer(morphSubject.getHitstun() + morphSubject.getHitstop(), 1, function(){
		cpuHitstunActive = false;
		if(cpuHitstunTimer != null){
			morphSubject.removeTimer(cpuHitstunTimer);
		}
	}, {persistent: true});
	if(cpuPercentSprite.currentFrame == cpuPercentSprite.totalFrames){
		outroDirect = (event.data.foe.getX() < self.getX() ? 1 : -1);
		morphOnKO();
	}
}

function morphOnKO(){
	morphSubject.toState(CState.FALL);
	morphSubject.removeEventListener(GameObjectEvent.HIT_RECEIVED, morphOnHit);
	match.removeEventListener(MatchEvent.TICK_END, morphTickEnd);
	match.removeEventListener(MatchEvent.TICK_START, morphTickStart);
	morphSubject.removeEventListener(CharacterEvent.LEDGE_GRAB, morphOnLedgeGrab);
	morphSubject.removeEventListener(GameObjectEvent.GRAB_RECEIVED, morphGrabbed);
	morphSubject.removeShader(morphShader);
	morphSubject.getDamageCounterRenderSprite().removeShader(morphShader);
	cpuArrowSprite.dispose();
	cpuPercentSprite.dispose();
	camera.deleteTarget(plyrGhost);
	plyrGhostSprite.dispose();
	plyrGhost.destroy();
	camera.shake(17, 18);
	match.freezeScreen(20, [camera]);
	AudioClip.play(GlobalSfx.PARRY);
	AudioClip.play(self.getResource().getContent("land"));

	self.unattachFromFloor();
	self.updateGameObjectStats({ghost: true, aerialSpeedCap: 20, aerialFriction: 0.4});
	self.setXVelocity(outroForce * outroDirect);
	if(outroDirect < 0){
		self.faceLeft();
	}
	else{
		self.faceRight();
	}
	Common.startFadeIn();
	self.toState(STATE_OUT, nameExt + "outro");
}

function morphReturnInBounds(){
    if(morphSubject.getX() > stage.getCameraBounds().getX() + stage.getCameraBounds().getRectangle().width + -camWallBuffer){
        morphSubject.setX(stage.getCameraBounds().getX() + stage.getCameraBounds().getRectangle().width + -camWallBuffer);
    }
    else if(morphSubject.getX() < stage.getCameraBounds().getX() + camWallBuffer){
        morphSubject.setX(stage.getCameraBounds().getX() + camWallBuffer);
    }

    if(morphSubject.getY() > stage.getCameraBounds().getY() + stage.getCameraBounds().getRectangle().height + -camWallBuffer){
        morphSubject.setX(cpuGroundPos[0]);
		morphSubject.setY(cpuGroundPos[1]);
    }
    else if(morphSubject.getY() < stage.getCameraBounds().getY() + camWallBuffer){
        morphSubject.setY(stage.getCameraBounds().getY() + camWallBuffer);
    }
}

function checkForMorphis(){
	var temp:Array<Projectile> = match.getProjectiles();
	if(temp.length > 0){
		for(i in 0...temp.length){
			if(temp[i].getAnimation() == "morphiCheckObj"){
				return true;
			}
		}
	}
	return false;
}
