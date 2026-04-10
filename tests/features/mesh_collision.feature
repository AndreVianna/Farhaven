Feature: Mesh Collision
  Placed structures have physical collision shapes.

  Scenario: Placed structure has collision shape
    Given a campfire PropDef with placeholder cylinder mesh
    When a collision shape is generated
    Then the shape is a CylinderShape3D
    And the radius matches the placeholder params

  Scenario: Overlapping placement rejected
    Given a structure at position 0, 0
    When another structure is placed at the same position
    Then the placement is rejected
