// GHOST SCRIPT
// -----------------------------------------------------------------------------------------------------------------------------------------
STATE_IDLE = 0;
STATE_STUNNED = 1;
STATE_DASH = 2;

var morphi = null;
var player:Character = null;
var arrowSprite:Sprite = null;
var spdRate = 0;
var spdCap = 0;
var sprite:Vfx = null;
var hitstunCurr = 40;
var dashSpd = 15;
var camWallBuffer = 20;
var hitThisFrame = false;
var arrowShader = null;
var arrowFilter = null;

function initialize(){
    self.addEventListener(GameObjectEvent.HITBOX_CONNECTED, onHitConnect, {persistent: true});
    self.addEventListener(GameObjectEvent.HIT_DEALT, onHitDealt, {persistent: true});
    self.addEventListener(GameObjectEvent.HIT_RECEIVED, onHitTaken, {persistent: true});


	self.exports = {
        setControlPlayer: function(plyr:Character, sprt, assist){
            player = plyr;
            sprite = sprt;
            morphi = assist;
            spdRate = player.getGameObjectStat("aerialSpeedAcceleration");
            spdCap = player.getGameObjectStat("aerialSpeedCap");
            dashSpd = spdCap * 2;
            self.updateGameObjectStats({cameraBoxHeight: plyr.getGameObjectStat("cameraBoxHeight"), cameraBoxWidth: plyr.getGameObjectStat("cameraBoxWidth"), cameraBoxOffsetX: plyr.getGameObjectStat("cameraBoxOffsetX"), cameraBoxOffsetY: plyr.getGameObjectStat("cameraBoxOffsetY")});

            arrowSprite = Sprite.create(self.getResource().getContent("morphi"));
            stage.getForegroundEffectsContainer().addChild(arrowSprite);
            arrowSprite.currentAnimation = "ghost_pointer";
            arrowSprite.alpha = 0;
            
            arrowShader = new RgbaColorShader();
            arrowShader.color = player.getPortColor();
            arrowShader.redMultiplier=1/3;
            arrowShader.greenMultiplier=1/2;
            arrowShader.blueMultiplier=1;
            arrowSprite.addShader(arrowShader);

            arrowFilter = new StrokeFilter();
            arrowFilter.color = 0xff000000;
            arrowFilter.size = 1;
            arrowSprite.addFilter(arrowFilter);
        }
    }
}

function update() {
    if(self.inState(STATE_IDLE)){
        if(player.getPlayerConfig().cpu){
            calculateCPUMovement();
        }
        else{
            calculateMovement();
        }
    }
    else if(self.inState(STATE_STUNNED)){
        sprite.playAnimation("hurt_light_middle");
        if(self.getXVelocity() > 0){
            self.faceLeft();
        }
        else if(self.getXVelocity() < 0){
            self.faceRight();
        }
        if(hitstunCurr <= 0){
            self.toState(STATE_IDLE);
        }
        else{
            hitstunCurr--;
        }

        if(Math.abs(self.getYVelocity()) > 0.2){
            self.setYVelocity(self.getYVelocity() + 0.1 * (self.getYVelocity() < 0 ? 1 : -1));
        }
        else{
            self.setYVelocity(0);
        }
    }
    else if(self.inState(STATE_DASH)){
        if(Math.abs(self.getYVelocity()) > 0.2){
            self.setYVelocity(self.getYVelocity() + 0.1 * (self.getYVelocity() < 0 ? 1 : -1));
        }
        else{
            self.setYVelocity(0);
        }
    }

    if(arrowSprite != null){
        if(arrowSprite.currentFrame == arrowSprite.totalFrames){
            arrowSprite.currentFrame = 0;
        }
        arrowSprite.advance();
        arrowSprite.x = self.getX();
        arrowSprite.y = self.getY() + -40;
        arrowSprite.rotation = getAngleFromPoints(self.getX(), self.getY() + -40, player.getX(), player.getY() + -40) + 90;
        if(self.getState() == STATE_IDLE){
            arrowSprite.alpha = 1;
        }
        else{
            arrowSprite.alpha = 0;
        }
    }

    keepInBounds();
    hitThisFrame = false;
}

function calculateMovement(){
    var hasMoved = false;
	if(player.getHeldControls().LEFT ){
        hasMoved = true;
        self.faceLeft();
        self.setXVelocity(self.getXVelocity() - spdRate);
        if(self.getXVelocity() < -spdCap){
            self.setXVelocity(-spdCap);
        }
    }
    else if(player.getHeldControls().RIGHT){
        hasMoved = true;
        self.faceRight();
        self.setXVelocity(self.getXVelocity() + spdRate);
        if(self.getXVelocity() > spdCap){
            self.setXVelocity(spdCap);
        }
    }

    if(player.getHeldControls().UP){
        hasMoved = true;
        self.setYVelocity(self.getYVelocity() - spdRate);
        if(self.getYVelocity() < -spdCap){
            self.setYVelocity(-spdCap);
        }
    }
    else if(player.getHeldControls().DOWN){
        hasMoved = true;
        self.setYVelocity(self.getYVelocity() + spdRate);
        if(self.getYVelocity() > spdCap){
            self.setYVelocity(spdCap);
        }
    }
    else if(Math.abs(self.getYVelocity()) > 0.2){
        self.setYVelocity(self.getYVelocity() + 0.1 * (self.getYVelocity() < 0 ? 1 : -1));
    }
    else{
        self.setYVelocity(0);
    }

    if(player.getPressedControls().ATTACK || player.getPressedControls().SPECIAL || player.getPressedControls().SHIELD){
        AudioClip.play(GlobalSfx.AIRDASH);
        self.toState(STATE_DASH);
    }

    if(hasMoved){
        if(sprite.getAnimation() != "jump_loop"){
            sprite.playAnimation("jump_loop");
        }
    }
    else if(sprite.getAnimation() != "fall_loop"){
        sprite.playAnimation("fall_loop");
    }
}

function calculateCPUMovement(){
    var hasMoved = false;
	if(player.getX() < self.getX()){
        hasMoved = true;
        self.faceLeft();
        self.setXVelocity(self.getXVelocity() - spdRate);
        if(self.getXVelocity() < -spdCap){
            self.setXVelocity(-spdCap);
        }
    }
    else if(player.getX() > self.getX()){
        hasMoved = true;
        self.faceRight();
        self.setXVelocity(self.getXVelocity() + spdRate);
        if(self.getXVelocity() > spdCap){
            self.setXVelocity(spdCap);
        }
    }

    if(player.getY() < self.getY()){
        hasMoved = true;
        self.setYVelocity(self.getYVelocity() - spdRate);
        if(self.getYVelocity() < -spdCap){
            self.setYVelocity(-spdCap);
        }
    }
    else if(player.getY() > self.getY()){
        hasMoved = true;
        self.setYVelocity(self.getYVelocity() + spdRate);
        if(self.getYVelocity() > spdCap){
            self.setYVelocity(spdCap);
        }
    }
    else if(Math.abs(self.getYVelocity()) > 0.2){
        self.setYVelocity(self.getYVelocity() + 0.1 * (self.getYVelocity() < 0 ? 1 : -1));
    }
    else{
        self.setYVelocity(0);
    }

    if(getDistFromPoints(self.getX(), self.getY(), player.getX(), player.getY()) < 300 && Random.getInt(0, 5) == 3){
        AudioClip.play(GlobalSfx.AIRDASH);
        self.toState(STATE_DASH);
    }

    if(hasMoved){
        if(sprite.getAnimation() != "jump_loop"){
            sprite.playAnimation("jump_loop");
        }
    }
    else if(sprite.getAnimation() != "fall_loop"){
        sprite.playAnimation("fall_loop");
    }
}

function calculateDash(){
    if(player.getHeldControls().UP && player.getHeldControls().RIGHT){
        sprite.playAnimation("airdash_forward_up");
        self.faceRight();
        self.setYVelocity(-dashSpd / 1.2);
        self.setXVelocity(dashSpd / 1.2);
    }
    else if(player.getHeldControls().UP && player.getHeldControls().LEFT){
        sprite.playAnimation("airdash_forward_up");
        self.faceLeft();
        self.setYVelocity(-dashSpd / 1.2);
        self.setXVelocity(-dashSpd / 1.2);
    }
    else if(player.getHeldControls().UP){
        sprite.playAnimation("airdash_up");
        self.setYVelocity(-dashSpd);
    }
    else if(player.getHeldControls().DOWN && player.getHeldControls().RIGHT){
        sprite.playAnimation("airdash_forward_down");
        self.faceRight();
        self.setYVelocity(dashSpd / 1.2);
        self.setXVelocity(dashSpd / 1.2);
    }
    else if(player.getHeldControls().DOWN && player.getHeldControls().LEFT){
        sprite.playAnimation("airdash_forward_down");
        self.faceLeft();
        self.setYVelocity(dashSpd / 1.2);
        self.setXVelocity(-dashSpd / 1.2);
    }
    else if(player.getHeldControls().DOWN){
        sprite.playAnimation("airdash_down");
        self.setYVelocity(dashSpd);
    }
    else if(player.getHeldControls().RIGHT){
        sprite.playAnimation("airdash_forward");
        self.faceRight();
        self.setXVelocity(dashSpd);
    }
    else if(player.getHeldControls().LEFT){
        sprite.playAnimation("airdash_forward");
        self.faceLeft();
        self.setXVelocity(-dashSpd);
    }
    else{
        if(self.isFacingRight()){
            sprite.playAnimation("airdash_forward");
            self.setXVelocity(dashSpd);
        }
        else{
            sprite.playAnimation("airdash_forward");
            self.setXVelocity(-dashSpd);
        }
    }
}

function calculateCPUDash(){
    if(player.getY() < self.getY() && player.getX() + 60 > self.getX()){
        sprite.playAnimation("airdash_forward_up");
        self.faceRight();
        self.setYVelocity(-dashSpd / 1.2);
        self.setXVelocity(dashSpd / 1.2);
    }
    else if(player.getY() < self.getY() && player.getX() - 60 < self.getX()){
        sprite.playAnimation("airdash_forward_up");
        self.faceLeft();
        self.setYVelocity(-dashSpd / 1.2);
        self.setXVelocity(-dashSpd / 1.2);
    }
    else if(player.getY() < self.getY()){
        sprite.playAnimation("airdash_up");
        self.setYVelocity(-dashSpd);
    }
    else if(player.getY() > self.getY() && player.getX() + 60 > self.getX()){
        sprite.playAnimation("airdash_forward_down");
        self.faceRight();
        self.setYVelocity(dashSpd / 1.2);
        self.setXVelocity(dashSpd / 1.2);
    }
    else if(player.getY() > self.getY() && player.getX() - 60 < self.getX()){
        sprite.playAnimation("airdash_forward_down");
        self.faceLeft();
        self.setYVelocity(dashSpd / 1.2);
        self.setXVelocity(-dashSpd / 1.2);
    }
    else if(player.getY() > self.getY()){
        sprite.playAnimation("airdash_down");
        self.setYVelocity(dashSpd);
    }
    else if(player.getX() > self.getX()){
        sprite.playAnimation("airdash_forward");
        self.faceRight();
        self.setXVelocity(dashSpd);
    }
    else if(player.getX() < self.getX()){
        sprite.playAnimation("airdash_forward");
        self.faceLeft();
        self.setXVelocity(-dashSpd);
    }
}

function keepInBounds(){
    if(self.getX() > stage.getCameraBounds().getX() + stage.getCameraBounds().getRectangle().width + -camWallBuffer){
        self.setX(stage.getCameraBounds().getX() + stage.getCameraBounds().getRectangle().width + -camWallBuffer);
    }
    else if(self.getX() < stage.getCameraBounds().getX() + camWallBuffer){
        self.setX(stage.getCameraBounds().getX() + camWallBuffer);
    }

    if(self.getY() > stage.getCameraBounds().getY() + stage.getCameraBounds().getRectangle().height + -camWallBuffer){
        self.setY(stage.getCameraBounds().getY() + stage.getCameraBounds().getRectangle().height + -camWallBuffer);
    }
    else if(self.getY() < stage.getCameraBounds().getY() + camWallBuffer){
        self.setY(stage.getCameraBounds().getY() + camWallBuffer);
    }
}

function onHitConnect(event:GameObjectEvent){
    if(event.data.foe.getUid() == player.getUid() && !hitThisFrame){
        var dmge = 15;
        if(self.getAnimation() == "ghost_dash"){
            dmge = 20;
        }
        event.data.hitboxStats.hitstopOffset = 6;
        event.data.hitboxStats.flinch = true;
        hitstunCurr = 28;
        self.toState(STATE_STUNNED);
        if(!morphi.exports.updateMorphiDamage(dmge, self)){
            camera.shake(12, 14);
            AudioClip.play(GlobalSfx.SHIELD_HIT_0);
        }
        var angle = getAngleFromPoints(self.getX(), self.getY(), event.data.foe.getX(), event.data.foe.getY());
        self.setXVelocity(Math.calculateXVelocity(15, angle));
        self.setYVelocity(Math.calculateYVelocity(15, angle));
        hitThisFrame = true;
    }
}

function onHitTaken(){
    hitstunCurr = self.getHitstun() * 2;
    self.setDamage(0);
    self.toState(STATE_STUNNED);
}

function onHitDealt(event:GameObjectEvent){
    
}

function getAngleFromPoints(x1, y1, x2, y2): Float{
    var pos1 = new Point(x1, -y1);
    var pos2 = new Point(x2, -y2);
    var result = Math.getAngleBetween(pos1, pos2);
    pos1.dispose();
    pos2.dispose();
    return result;
}

function getDistFromPoints(x1, y1, x2, y2): Float{
    var pos1 = new Point(x1, -y1);
    var pos2 = new Point(x2, -y2);
    var result = Math.getDistance(pos1, pos2);
    pos1.dispose();
    pos2.dispose();
    return result;
}


function onTeardown(){
    arrowSprite.removeFilter(arrowFilter);
    arrowSprite.removeShader(arrowShader);
    arrowSprite.dispose();
}
