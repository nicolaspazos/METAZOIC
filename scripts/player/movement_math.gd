class_name MovementMath
extends RefCounted
## Stateless movement/resource calculations shared by the controller and tests.


static func camera_relative(input: Vector2, camera_basis: Basis) -> Vector3:
	var direction := camera_basis.z * input.y + camera_basis.x * input.x
	direction.y = 0.0
	return direction.normalized()


static func horizontal_velocity(current: Vector3, target: Vector3,
		acceleration: float, delta: float) -> Vector3:
	return Vector3(
		move_toward(current.x, target.x, acceleration * delta),
		current.y,
		move_toward(current.z, target.z, acceleration * delta)
	)


static func regenerate_resource(current: float, maximum: float, rate: float,
		delta: float) -> float:
	return minf(maximum, current + rate * delta)


static func mantle_position(start: Vector3, target: Vector3, progress: float,
		arc_height: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var position := start.lerp(target, t)
	position.y += sin(t * PI) * arc_height
	return position
