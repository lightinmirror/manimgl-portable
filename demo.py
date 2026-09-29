"""Small end-to-end smoke test.

Run with::

    manim-env\\Scripts\\python.exe -m manimlib demo.py Demo -w -m

The scene exercises Text, mathematical Tex, CJK Tex, geometry, and video output.
Use showcase.py for the longer feature tour.
"""

from manimlib import (
    BLUE_B, DOWN, GREY_B, GREY_D, ORIGIN, UP, YELLOW,
    FadeIn, GrowFromCenter, RoundedRectangle, Scene, Tex, Text, VGroup, Write,
)


class Demo(Scene):
    def construct(self):
        title = Text("便携 manimgl 验证", font_size=62)
        rule = RoundedRectangle(
            width=title.get_width() + 0.5, height=0.06,
            corner_radius=0.03, color=GREY_B, fill_opacity=1,
        )
        rule.next_to(title, DOWN, 0.28)

        formula = Tex(
            r"\frac{a}{b} + \sum_{i=1}^{n} x_i^2 = \int_0^\infty e^{-t}\,dt",
            font_size=48, fill_color=BLUE_B,
        )
        cjk = Tex(
            r"\text{中文公式} \quad \mathbb{R} \leq \mathbb{C}",
            font_size=48, fill_color=YELLOW,
        )
        body = VGroup(formula, cjk).arrange(DOWN, buff=0.5)
        body.next_to(rule, DOWN, 0.55)

        content = VGroup(title, rule, body)
        # 不重新居中：title 在 ORIGIN、rule/body 往下挂 → 整组沉到画面中心以下，外框底边会被切掉
        content.move_to(ORIGIN)
        frame = RoundedRectangle(
            width=content.get_width() + 2.2,
            height=content.get_height() + 1.6,
            corner_radius=0.35, color=GREY_D, stroke_width=2,
        ).move_to(content)

        self.play(FadeIn(frame, scale=0.95), run_time=0.5)
        self.play(Write(title), run_time=0.7)
        self.play(GrowFromCenter(rule), run_time=0.3)
        self.play(Write(formula), run_time=0.9)
        self.play(FadeIn(cjk, UP * 0.25), run_time=0.5)
        self.wait(0.7)
