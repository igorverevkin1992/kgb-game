shader_type canvas_item;
// ЭЛТ-эффект поверх всего стола: виньетка, тонкие строки развёртки и зерно плёнки.
// Рисует только полупрозрачное затемнение — экран не перечитывает (работает в Compatibility и вебе).

uniform float strength : hint_range(0.0, 1.0) = 1.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 d = UV - vec2(0.5);
	float vig = smoothstep(0.38, 0.9, length(d * vec2(1.0, 0.85)));
	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	float grain = rand(floor(FRAGCOORD.xy / 2.0) + vec2(floor(TIME * 24.0) * 7.13, 3.7));
	float a = vig * 0.5 + scan * 0.045 + grain * 0.05;
	COLOR = vec4(vec3(0.04, 0.03, 0.02) + vec3(grain * 0.25), clamp(a, 0.0, 0.85) * strength);
}
