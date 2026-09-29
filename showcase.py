"""Short feature tour for the portable build.

Run with::

    manim-env\\Scripts\\python.exe -m manimlib showcase.py Showcase -w -m

It covers mixed-language Text, multi-line Tex, geometry, axes, and camera movement.
"""

from manimlib import (
    DOWN, GREY, LEFT, ORIGIN, RIGHT, UP, YELLOW,
    Axes, Brace, Circle, FadeIn, FadeOut, GrowFromCenter, Indicate, Line,
    Polygon, RegularPolygon, Scene, Square, Tex, Text, Transform, VGroup, Write,
)


class Showcase(Scene):
    # ---------------------------------------------------------------- 0 片头
    def intro(self):
        title = Text("manimgl-portable", font_size=76)
        sub = Text("零安装 · 中文可用 · 离线可跑", font_size=32, fill_color=GREY)
        block = VGroup(title, sub).arrange(DOWN, buff=0.5)
        block.move_to(ORIGIN)
        self.play(Write(title), run_time=1.0)
        self.play(FadeIn(sub, UP * 0.3), run_time=0.6)
        self.wait(0.8)
        self.play(FadeOut(VGroup(title, sub)), run_time=0.6)

    # ------------------------------------------------- 1 Text：中英混排与变色
    def text_demo(self):
        t = Text("Text：中文与 English 混排", font_size=56,
                 t2c={"Text": YELLOW, "English": "#5ac8fa"})
        t2 = Text("部分变色 t2c · 加粗 t2w · 斜体 t2s", font_size=36, fill_color=GREY)
        block = VGroup(t, t2).arrange(DOWN, buff=0.5)
        block.move_to(ORIGIN)
        self.play(FadeIn(t, UP * 0.3), run_time=0.7)
        self.play(Indicate(t, scale_factor=1.06, color=YELLOW), run_time=0.8)
        self.play(FadeIn(t2), run_time=0.5)
        self.wait(0.7)
        self.play(FadeOut(VGroup(t, t2)), run_time=0.5)

    # ------------------------------------------------ 2 Tex：公式、中文、多行
    def tex_demo(self):
        head = Text("Tex：公式与中文", font_size=40, fill_color=GREY)
        f = Tex(
            r"\sum_{i=1}^{n} x_i^2 + \int_0^\infty e^{-t}\,dt "
            r"= \frac{a}{b} \rightarrow \infty",
            font_size=52,
        )
        f2 = Tex(r"\text{中文公式} \quad \mathbb{R} \leq \mathbb{C}",
                 font_size=52, fill_color=YELLOW)
        body = VGroup(f, f2).arrange(DOWN, buff=0.55)
        block = VGroup(head, body).arrange(DOWN, buff=0.6)
        block.move_to(ORIGIN)
        self.play(FadeIn(head), run_time=0.4)
        self.play(Write(f), run_time=1.2)
        self.play(FadeIn(f2, UP * 0.3), run_time=0.6)
        self.wait(0.9)
        self.play(FadeOut(VGroup(head, body)), run_time=0.5)

    # ------------------------------------------------------ 3 图形与变换
    def shape_demo(self):
        sq = Square(side_length=1.6, color="#4cd964", fill_opacity=0.3)
        circ = Circle(radius=0.9, color="#ff9500", fill_opacity=0.3)
        poly = RegularPolygon(6, color="#af52de", fill_opacity=0.3)
        row = VGroup(sq, circ, poly).arrange(RIGHT, buff=0.9)
        row.set_color_by_gradient("#4cd964", "#ff9500", "#af52de")

        self.play(GrowFromCenter(row), run_time=0.8)
        self.play(row.animate.arrange(RIGHT, buff=0.4).scale(1.15), run_time=0.7)
        pentagon = Polygon(
            [0, 1, 0], [1, 0.2, 0], [0.5, -1, 0],
            [-0.5, -0.8, 0], [-1, 0.4, 0], [-0.5, 1, 0],
            color="#ff9500", fill_opacity=0.4,
        )
        self.play(Transform(row[1], pentagon), run_time=0.8)
        self.wait(0.5)
        self.play(FadeOut(row), run_time=0.5)

    # -------------------------------------------------------- 4 坐标轴作图
    def plot_demo(self):
        ax = Axes(x_range=[-3, 3, 1], y_range=[-1.5, 4, 1],
                  axis_config={"include_tip": True})
        curve = ax.get_graph(lambda x: 0.4 * x ** 2 - 1, color=YELLOW)
        label = ax.get_graph_label(curve, r"y=\frac{2}{5}x^2-1", x=2.0)

        self.play(FadeIn(ax), run_time=0.6)
        self.play(Write(curve), run_time=1.0)
        self.play(FadeIn(label), run_time=0.5)

        dot = Circle(radius=0.08, color=YELLOW, fill_opacity=1).move_to(
            ax.c2p(-2.2, 0.4 * 2.2 ** 2 - 1))
        br = Brace(Line(ax.c2p(-2.2, 0), ax.c2p(-2.2, 0.4 * 2.2 ** 2 - 1)), LEFT)
        self.play(FadeIn(dot), run_time=0.3)
        self.play(GrowFromCenter(br), run_time=0.5)
        self.wait(0.8)
        self.play(FadeOut(VGroup(ax, curve, label, dot, br)), run_time=0.5)

    # ------------------------------------------------------- 5 相机运动
    def camera_demo(self):
        grid = VGroup(*[
            Text(f"{i}", font_size=40, fill_color=GREY).move_to(
                [((i % 5) - 2) * 1.6, ((i // 5) - 0.5) * 1.6, 0])
            for i in range(10)
        ])
        cap = Text("相机也能动", font_size=52)
        self.play(FadeIn(grid), run_time=0.5)
        self.play(FadeIn(cap), run_time=0.5)
        self.play(self.camera.frame.animate.scale(0.55).move_to(grid[7]),
                  run_time=1.2)
        self.wait(0.6)
        self.play(self.camera.frame.animate.to_default_state(), run_time=0.8)
        self.play(FadeOut(VGroup(grid, cap)), run_time=0.5)

    # ------------------------------------------------------------- 6 片尾
    def outro(self):
        t = Text("开始创作吧", font_size=64)
        cmd = Text("manimgl-portable.exe your_scene.py YourScene -w -l",
                   font_size=26, fill_color=GREY)
        block = VGroup(t, cmd).arrange(DOWN, buff=0.7)
        block.move_to(ORIGIN)
        self.play(FadeIn(t, UP * 0.3), run_time=0.7)
        self.play(FadeIn(cmd), run_time=0.6)
        self.wait(1.4)
        self.play(FadeOut(VGroup(t, cmd)), run_time=0.6)

    def construct(self):
        self.intro()
        self.text_demo()
        self.tex_demo()
        self.shape_demo()
        self.plot_demo()
        self.camera_demo()
        self.outro()
