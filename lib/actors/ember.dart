import 'dart:ui';
import 'package:flame/components.dart';
import '../ember_quest.dart';
import 'package:flutter/services.dart';
import 'package:flame/collisions.dart';
import '../objects/cherry.dart';
import '../objects/ground_block.dart';
import '../objects/platform_block.dart';
import 'package:flame/effects.dart';
import '../objects/star.dart';
import 'water_enemy.dart';

class EmberPlayer extends SpriteAnimationComponent
    with KeyboardHandler, CollisionCallbacks, HasGameReference<EmberQuestGame> {

  EmberPlayer({
    required super.position,
  }) : super(size: Vector2.all(64), anchor: Anchor.center);

  int horizontalDirection = 0;
  final Vector2 velocity = Vector2.zero();
  final double moveSpeed = 200;
  final Vector2 fromAbove = Vector2(0, -1);
  bool isOnGround = false;
  final double gravity = 15;
  final double jumpSpeed = 600;
  final double terminalVelocity = 150;

  bool hasJumped = false;
  bool hitByEnemy = false;

  bool isInvincible = false;
  double invincibleTimer = 0.0;
  static const double powerUpDuration = 5.0;
  static const double blinkThreshold = 2.0;
  bool isBlinking = false;
  OpacityEffect? blinkFX;


  @override
  void onLoad() {
    animation = SpriteAnimation.fromFrameData(
      game.images.fromCache('ember.png'),
      SpriteAnimationData.sequenced(
        amount: 4,
        textureSize: Vector2.all(16),
        stepTime: 0.12,
      ),
    );
    add(CircleHitbox());
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    horizontalDirection = 0;
    horizontalDirection += (keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft))
        ? -1
        : 0;
    horizontalDirection += (keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight))
        ? 1
        : 0;
    hasJumped = keysPressed.contains(LogicalKeyboardKey.space);
    return true;
  }

  @override
  void update(double dt) {
    velocity.x = horizontalDirection * moveSpeed;

    game.objectSpeed = 0;
    // Prevent ember from going backwards at screen edge.
    if (position.x - 36 <= 0 && horizontalDirection < 0) {
      velocity.x = 0;
    }
    if (position.x + 64 >= game.size.x / 2 && horizontalDirection > 0) {
      velocity.x = 0;
      game.objectSpeed = -moveSpeed;
    }

    // Apply basic gravity
    velocity.y += gravity;

    // Determine if ember has jumped
    if (hasJumped) {
      if (isOnGround) {
        velocity.y = -jumpSpeed;
        isOnGround = false;
      }
      hasJumped = false;
    }

    // Prevent ember from jumping to crazy fast as well as descending too fast and
    // crashing through the ground or a platform.
    velocity.y = velocity.y.clamp(-jumpSpeed, terminalVelocity);

    position += velocity * dt;

    if (horizontalDirection < 0 && scale.x > 0) {
      flipHorizontally();
    } else if (horizontalDirection > 0 && scale.x < 0) {
      flipHorizontally();
    }

    // If ember fell in pit, then game over.
    if (position.y > game.size.y + size.y) {
      game.health = 0;
    }

    if (game.health <= 0) {
      removeFromParent();
    }

    //Invincibility Timer
    if (invincibleTimer > 0) {
      invincibleTimer -= dt;

      if(!isBlinking && invincibleTimer <= blinkThreshold){
        startBlinkFX();
        isBlinking = true;
      }
      if (invincibleTimer <= 0) {
        endPowerUp();
      }
    }

    super.update(dt);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is GroundBlock || other is PlatformBlock) {
      if (intersectionPoints.length == 2) {
        // Calculate the collision normal and separation distance.
        final mid = (intersectionPoints.elementAt(0) +
            intersectionPoints.elementAt(1)) / 2;

        final collisionNormal = absoluteCenter - mid;
        final separationDistance = (size.x / 2) - collisionNormal.length;
        collisionNormal.normalize();

        // If collision normal is almost upwards,
        // ember must be on ground.
        if (fromAbove.dot(collisionNormal) > 0.9) {
          isOnGround = true;
        }

        // Resolve collision by moving ember along
        // collision normal by separation distance.
        position += collisionNormal.scaled(separationDistance);
      }
    }

    if (other is Star) {
      other.removeFromParent();
      game.starsCollected++;
    }
    if (other is Cherry) {
      other.removeFromParent();
      powerUp();
    }

    if (other is WaterEnemy) {
      if (isInvincible) {
        other.removeFromParent();
      }
      else {
        hit();
      }
    }
    super.onCollision(intersectionPoints, other);
  }


  // This method runs an opacity effect on ember
  // to make it blink.
  void hit() {
    if (!hitByEnemy) {
      game.health--;
      hitByEnemy = true;
    }
    add(
      OpacityEffect.fadeOut(
        EffectController(
          alternate: true,
          duration: 0.1,
          repeatCount: 5,
        ),
      )
        ..onComplete = () {
          hitByEnemy = false;
        },
    );
  }

  void powerUp() {
    // Start/refresh the timer
    invincibleTimer = powerUpDuration;

    // If we just became invincible, turn red
    if (!isInvincible) {
      isInvincible = true;
      applyRed();
    }
    //stop blinking after refresh
    if (isBlinking){
      stopBlinkFX();
      isBlinking = false;
      opacity = 1.0;
    }
  }

  void endPowerUp() {
    isInvincible = false;
    stopBlinkFX();
    removeRed();
    opacity = 1.0;
  }

  void applyRed(){
    paint.colorFilter = const ColorFilter.mode(Color(0xFFFF0000), BlendMode.modulate);
  }

  void removeRed(){
    paint.colorFilter = null;
  }

  void startBlinkFX() {
    // Blink for the entire duration
    const period = 0.2; // seconds per blink
    final repeats = (invincibleTimer / period).ceil();
    blinkFX = OpacityEffect.to(
      0.3,
      EffectController(
        alternate: true,
        duration: period,
        repeatCount: repeats,
      ),
    );
    add(blinkFX!);
  }

  void stopBlinkFX() {
    blinkFX?.removeFromParent();
    blinkFX = null;
  }
}