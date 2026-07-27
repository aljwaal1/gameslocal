# Procedural professional penalty scene

This build no longer depends on the `pro_penalty_arena.jpg` bitmap at runtime.
The stadium, pitch, goal, net, striker, goalkeeper, ball, aiming guide and shot effects are rendered by Flutter `CustomPainter` so they remain visible on older Android devices.
