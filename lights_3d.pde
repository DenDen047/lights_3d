import processing.opengl.*;
import processing.serial.*;

/* === Global variable === */
// serial
Serial myPort;
// draw
int angle, size;
int _;
Differential dif;
int ball_num;
PhysicalBall[] ball;

boolean theworld;



class Position {
    int x, y;
    int r, theta;

    Position () {
        x = 0;
        y = 0;
        r = 0;
        theta = 0;
    }

    void update_cartesian (int a, int b) {
        x = a;
        y = b;
        r = int(sqrt(sq(x) + sq(y)));
        theta = int(degrees(atan2(x, y)));
    }
}


class Differential {
    int stack_size;
    Position[] point;
    int loop_count;

    int dr, dtheta;

    int r, theta;

    Differential () {
        loop_count = 1;
        stack_size = 10;
        point = new Position[stack_size];
        for (int i=0; i<stack_size; i++) {
            point[i] = new Position();
        }
    }

    void update(int x1, int y1, int x2, int y2) {
        int ago = (loop_count - 1 < 0) ? stack_size - 1 : loop_count - 1;
        int now = loop_count;

        int xc = (x1 + x2) / 2;
        int yc = (y1 + y2) / 2;
        int x = xc - x1;
        int y = yc - y1;

        point[now].update_cartesian(x, y);
        loop_count = (loop_count + 1) % stack_size;

        dr = point[now].r - point[ago].r;
        dtheta = point[now].theta - point[ago].theta;

        r = point[now].r;
        theta = point[now].theta;
    }
}


class Light {
    PImage img;
    float posX, posY, posZ;

    Light (float r, float g, float b) {
        img = createLight(r, g, b);
        posX = 0.0;
        posY = 0.0;
        posZ = 0.0;
    }

    // 光る球体の画像を生成する関数
    PImage createLight(float rPower, float gPower, float bPower) {
        int side = 200;     // 1辺の大きさ
        float center = side / 2.0;  // 中心座標

        // 画像を生成
        PImage img = createImage(side, side, RGB);

        // 画像の一つ一つのピクセルの色を設定する
        for (int y = 0; y < side; y++) {
        for (int x = 0; x < side; x++) {
            float distance = (sq(center - x) + sq(center - y)) / 50.0;
            int r = int( (255 * rPower) / distance );
            int g = int( (255 * gPower) / distance );
            int b = int( (255 * bPower) / distance );
            img.pixels[x + y * side] = color(r, g, b);
        }
        }
        return img;
    }

    void position_set(float x, float y, float z) {
        posX = x;
        posY = y;
        posZ = z;
    }

    void draw_cartesian(float x, float y, float z) {
        pushMatrix();
        translate(posX, posY, posZ);
        // 画像の座標へ原点を移動
        translate(x, y, z);
        // 画像を描画
        image(img, 0, 0);
        popMatrix();
    }

    void draw_polar_y(float r, float angle) {
        pushMatrix();
        translate(posX, posY, posZ);
        // 画像の座標へ原点を移動
        rotateY(radians(angle));
        translate(r, 0, 0);
        rotateY(radians(-angle));
        // 画像を描画
        image(img, 0, 0);
        popMatrix();
    }

    void move() {
        translate(posX, posY, posZ);
    }
    void draw() {
        image(img, 0, 0);
    }

    void changeColor(float r, float g, float b) {
        img = createLight(r, g, b);
    }
}

class PhysicalBall {
    Light ball;
    float mass, gravity;
    float posX, posY, posZ;
    float speedX, speedY, speedZ;
    float rotX, rotY, rotZ;

    PhysicalBall (float x, float y, float z, float sx, float sy, float sz, float r, float g, float b) {
        ball = new Light(r, g, b);
        gravity = 0.98;
        posX = x;
        posY = y;
        posZ = z;
        speedX = sx;
        speedY = sy;
        speedZ = sz;

        rotX = 0.0;
        rotY = 0.0;
        rotZ = 0.0;
    }

    void updateSpeed() {
        float distance = sqrt(sq(posX) + sq(posY) + sq(posZ));
        speedX += -gravity * posX / distance;
        speedY += -gravity * posY / distance;
        speedZ += -gravity * posZ / distance;
    }

    void updatePosition() {
        posX += speedX;
        posY += speedY;
        posZ += speedZ;
    }

    void updateRotate(float x, float y, float z) {
        rotX = x;
        rotY = y;
        rotZ = z;
    }

    void draw(boolean stop) {
        if (!stop) {
            updateSpeed();
            updatePosition();
        }

        pushMatrix();

        rotateX(radians(rotX));
        rotateY(radians(rotY));
        rotateZ(radians(rotZ));
        ball.position_set(posX, posY, posZ);
        ball.move();
        rotateX(radians(-rotX));
        rotateY(radians(-rotY));
        rotateZ(radians(-rotZ));

        ball.draw();

        popMatrix();
    }
}


void setup(){
    // setup of serial
    printArray(Serial.list());
    myPort = new Serial(this, Serial.list()[1], 115200);

    // setup of drawing
    // size(1000, 700, OPENGL);
    // size(1000, 700, P3D);
    fullScreen(OPENGL);
    // zテストを無効化
    hint(DISABLE_DEPTH_TEST);
    // 加算合成
    blendMode(ADD);
    imageMode(CENTER);
    // 画像の生成

    // others
    angle = 0;
    size = 150;
    ball_num = 100;

    theworld = false;

    dif = new Differential();
    ball = new PhysicalBall[ball_num];

    for (int i=0; i<ball_num; i++) {
        ball[i] = new PhysicalBall(
            random(-200, 200), random(-200, 200), random(-200, 200),
            random(-10, 10), random(-10, 10), random(-10, 10),
            random(0.5, 0.8), random(0.5, 0.8), random(0.5, 0.8));
    }
}

void draw(){
    /* === Setup === */
    String input = "0, 0,  0, 0,  0, 0";


    /* === Serial === */
    while (myPort.available() > 0) {
        input = myPort.readString();
        if (input != null) {
            println(input);
        }
    }

    String[] s = splitTokens(input, "\n");
    input = s[s.length - 1];
    s = splitTokens(input, ",");
    int[] value = new int[s.length];
    for (int i=0; i<s.length; i++) {
        value[i] = Integer.parseInt(trim(s[i]));  // string to int
    }

    // get 'r' and 'theta'
    int x1 = value[0];
    int y1 = value[1];
    int x2 = value[2];
    int y2 = value[3];
    int x3 = value[4];
    int y3 = value[5];

    if (x1 * y1 * x3 * y3 != 0) {
        dif.update(x1, y1, x3, y3);
        size += dif.dr;
        angle += dif.dtheta;
    }


    /* === Draw === */
    background(0, 15, 30);

    camera(
        0.0, 0.0, 700.0,    // eyeX, eyeY, eyeZ
        0.0, 0.0, 0.0,  // centerX, centerY, centerZ
        0.0, 1.0, 0.0   // upX, upY, upZ
    );

    stroke(255, 0, 0);
    line(0,0,0, 100,0,0);
    stroke(0, 255, 0);
    line(0,0,0, 0,100,0);
    stroke(0, 0, 255);
    line(0,0,0, 0,0,100);

    for (int i=0; i<ball_num; i++) {
        ball[i].updateRotate(0, 360.0 * i / ball_num + angle, 0);
        ball[i].draw(theworld);
    }


    println("dif.r: "+dif.r + "   " + theworld);
    if (theworld) {
        theworld = (dif.r > 70.0);
    } else {
        theworld = (dif.r > 200.0);
    }
}