import processing.sound.*;
import java.util.Collections;

int N = 100, M = 100; // Size of the habitat grid
int d = 3; // Dimension of data samples
float[][][] habitat;
int numAnts = 500;
Ant[] ants;
float p = 0.8; // Increased probability threshold to encourage movement
float evaporationRate = 0.01; // Further slowed down pheromone evaporation
color[][] inputData;

AudioIn in;
FFT fft;
Amplitude amp;
Waveform waveform;
PitchDetector pitchDetector;

int bands = 32; // Increased FFT bands for finer frequency response
float[] spectrum;

void setup() {
    println("Simulation started");
    fullScreen();
    habitat = new float[N][M][d];
    ants = new Ant[numAnts];
    inputData = new color[N][M];
    
    // Initialize habitat with random values
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < M; j++) {
            inputData[i][j] = color(random(255), random(255), random(255));
            habitat[i][j][0] = red(inputData[i][j]) / 255.0;
            habitat[i][j][1] = green(inputData[i][j]) / 255.0;
            habitat[i][j][2] = blue(inputData[i][j]) / 255.0;
        }
    }
    
    ArrayList<PVector> positions = new ArrayList<PVector>();
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < M; j++) {
            positions.add(new PVector(i, j));
        }
    }
    
    Collections.shuffle(positions);
    
    for (int i = 0; i < numAnts; i++) {
        PVector pos = positions.get(i % positions.size());
        ants[i] = new Ant((int)pos.x, (int)pos.y);
    }

    
    // Setup audio input
    in = new AudioIn(this, 0);
    in.start();
    
    amp = new Amplitude(this);
    amp.input(in);
    
    fft = new FFT(this, bands);
    fft.input(in);
    spectrum = new float[bands];
    
    waveform = new Waveform(this, 100); //100 is the number of samples you want read at a time
    waveform.input(in);
    
    pitchDetector = new PitchDetector(this);
    pitchDetector.input(in);  // Connect input
}

void draw() {
    background(0);
    
    fft.analyze(spectrum);
    float volume = amp.analyze() * 10; // Increased sensitivity to volume changes
    waveform.analyze();
    // Get pitch in Hz
    float pitchHZ = pitchDetector.analyze();  // Returns the detected pitch
    
    // Evaporate pheromone
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < M; j++) {
            habitat[i][j][0] *= (1 - evaporationRate);
        }
    }
    
    // Update and move ants
    for (Ant ant : ants) {
        ant.update(volume, pitchHZ, spectrum);
        ant.move();
        noStroke();
        fill(ant.antColor);
        ellipse(ant.x * width / N, ant.y * height / M, ant.size, ant.size);
    }
    
    // Check for collisions and mix colors
    for (int i = 0; i < numAnts; i++) {
        for (int j = i + 1; j < numAnts; j++) {
            if (dist(ants[i].x, ants[i].y, ants[j].x, ants[j].y) < (ants[i].size + ants[j].size) / 4) {
                ants[i].mixColor(ants[j]);
            }
        }
    }
}

class Ant {
    int x, y;
    float speed;
    float size;
    color antColor;
    
    Ant(int x, int y) {
        this.x = x;
        this.y = y;
        this.size = 80; // Bigger ants
        this.speed = 0.01; // Slower movement
        updateColor(new float[]{0, 0, 0});
    }
    
    void update(float volume, float pitch, float[] spectrum) {
        size = map(volume, 0, 1, 10, 40); // More noticeable size variations
        speed = map(pitch, 0, 1, 0.01, 0.3); // Slower, smoother speed changes
        updateColor(spectrum);
    }
    
    void move() {
        if (random(1) < p) {
            int bestX = x, bestY = y;
            float bestValue = -1;
            
            for (int i = -1; i <= 1; i++) {
                for (int j = -1; j <= 1; j++) {
                    int nx = constrain(x + i, 0, N - 1);
                    int ny = constrain(y + j, 0, M - 1);
                    if (nx != x || ny != y) {
                        float value = (habitat[nx][ny][0] + habitat[nx][ny][1] + habitat[nx][ny][2]) / 3.0;
                        value += random(-0.05, 0.05);
                        if (value > bestValue) {
                            bestValue = value;
                            bestX = nx;
                            bestY = ny;
                        }
                    }
                }
            }
            x = bestX;
            y = bestY;
        }
    }
  
  void updateColor(float[] spectrum) {
    int maxIndex = spectrum.length - 1;

    // Compute the average intensity of different frequency ranges
    float low = (spectrum[min(0, maxIndex)] + spectrum[min(1, maxIndex)] + spectrum[min(2, maxIndex)]) / 3;
    float mid = (spectrum[min(8, maxIndex)] + spectrum[min(9, maxIndex)] + spectrum[min(10, maxIndex)]) / 3;
    float high = (spectrum[min(18, maxIndex)] + spectrum[min(19, maxIndex)] + spectrum[min(20, maxIndex)]) / 3;

    // Apply a boost to mid and high frequencies to make green/blue stronger
    mid *= 17;  // Boost mid frequencies (green)
    high *= 65; // Boost high frequencies (blue)

    // Find the maximum value safely to normalize
    float maxVal = max(low, max(mid, max(high, 0.0001))); 

    // Normalize colors with better balance
    float r = map(low / maxVal, 0, 1, 50, 255);
    float g = map(mid / maxVal, 0, 1, 50, 255);
    float b = map(high / maxVal, 0, 1, 50, 255);

    // Gradually change color instead of instant switching (faster transition)
    antColor = lerpColor(antColor, color(r, g, b), 0.1); // Increased from 0.05 to 0.1
}
 
void mixColor(Ant other) {
    float newR = (red(this.antColor) + red(other.antColor)) / 2;
    float newG = (green(this.antColor) + green(other.antColor)) / 2;
    float newB = (blue(this.antColor) + blue(other.antColor)) / 2;

    // Gradually blend colors instead of sudden change
    this.antColor = lerpColor(this.antColor, color(newR, newG, newB), 0.1);
    other.antColor = lerpColor(other.antColor, color(newR, newG, newB), 0.1);
}

}
