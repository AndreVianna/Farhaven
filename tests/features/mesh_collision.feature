Feature: Mesh Collision
  Placed structures have physical collision shapes.

  Scenario: Placed structure has collision shape
    Given a campfire PropDef with an authored cylinder collision
    When collision shapes are generated
    Then the first shape is a CylinderShape3D
    And the radius matches the authored size

  Scenario: Overlapping placement rejected
    Given a structure at position 0, 0
    When another structure is placed at the same position
    Then the placement is rejected
