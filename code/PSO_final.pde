import processing.sound.*;

Particle[] particles;
PVector globalBestPos;
float globalBestVal;
AudioIn in;
FFT fft;
Amplitude amp;
Waveform waveform;
PitchDetector pitchDetector;

int bands = 32;
float[] spectrum;
ArrayList<Particle> activeParticles = new ArrayList<>();
int burstCooldown = 0;  // Cooldown to space out bursts

void setup() {
  fullScreen();
  globalBestVal = Float.MAX_VALUE;
  globalBestPos = new PVector(width / 2, height / 2); // Ensure it's initialized
  
  in = new AudioIn(this, 0);
  in.start();
  
  fft = new FFT(this, bands);
  fft.input(in);
  spectrum = new float[bands];
  
  amp = new Amplitude(this);
  amp.input(in);
  
  waveform = new Waveform(this, 100); //100 is the number of samples you want read at a time
  waveform.input(in);
  
  pitchDetector = new PitchDetector(this);
  pitchDetector.input(in);  // Connect input
}

// Declare at the top
float lastEnergy = 0;
float beatThreshold = 10;  // Adjust sensitivity, higher = triggers less frequently
float energySmoothing = 0.1;  // Helps avoid too many false triggers

void draw() {
  background(0);
  
  float volume = amp.analyze() * 10;
  //float pitch = pitchDetector.analyze();
  
  fft.analyze(spectrum);
  waveform.analyze();
  
  println("Spectrum: " + spectrum[0] + ", " + spectrum[1] + ", " + spectrum[2]);
  
  float spectralComplexity = 0;
  for (int i = 1; i < spectrum.length; i++) {
    spectralComplexity += abs(spectrum[i] - spectrum[i - 1]); // Measures spectral variation
  }
  spectralComplexity = map(spectralComplexity, 0, 5, 0, 1); // Normalize to 0-1
  
   // Compute Energy for Beat Detection
  float currentEnergy = 0;
  for (int i = 0; i < spectrum.length; i++) {
    currentEnergy += spectrum[i] * spectrum[i] * volume; // Sum of squared spectrum values
  }

  
  // Random burst logic
  if (currentEnergy > lastEnergy * beatThreshold) { // compares current frame's energy w previous frame, if it spikes beyond a threshold, considered a beat
    int burstSize = int(map(volume, 0, 1, 5, 30)); // Volume controls burst size
    spawnBurst(burstSize);
    burstCooldown = int(10 / (1 + spectralComplexity * 2)); // Random delay between bursts
  } else {
    burstCooldown--;
  }
  
  lastEnergy = lerp(lastEnergy, currentEnergy, energySmoothing);  // Smooth transition

  // Update and draw particles
  for (int i = activeParticles.size() - 1; i >= 0; i--) {
    Particle p = activeParticles.get(i);
    p.update();
    p.display();
  }
}

// Function to create bursts at different positions based on frequency spectrum
void spawnBurst(int spectralComplexity) {
  int count = int(0.5 + spectralComplexity * 1.5);
  count = constrain(count, 1, 15);
  for (int i = 0; i < count; i++) {
  float clusterX = random(width);   // Central explosion point
  float clusterY = random(height);
  color clusterColor = generateClusterColor(); // Generate one color for the cluster
  
  for (int x = 0; x < count; x++) {
    float angle = random(TWO_PI);  // Spread particles in a circular pattern
    float radius = random(5, 50);  // Randomized explosion radius
    float xPos = clusterX + cos(angle) * radius;
    float yPos = clusterY + sin(angle) * radius;
    
    Particle p = new Particle(new PVector(xPos, yPos));
    p.velocity = PVector.fromAngle(angle).mult(random(1, 5)); // Outward explosion force
    p.particleColor = clusterColor;  // Assign the same color to all particles in the burst
    p.lifespan = 255 + spectralComplexity * 30;  // Keep particles alive
    activeParticles.add(p);
  }
}
}

color generateClusterColor() {
  int maxIndex = spectrum.length - 1;
  
  float low = (spectrum[min(0, maxIndex)] + spectrum[min(1, maxIndex)] + spectrum[min(2, maxIndex)]) / 3;
  float mid = (spectrum[min(8, maxIndex)] + spectrum[min(9, maxIndex)] + spectrum[min(10, maxIndex)]) / 3;
  float high = (spectrum[min(18, maxIndex)] + spectrum[min(19, maxIndex)] + spectrum[min(20, maxIndex)]) / 3;

  mid *= 17;  
  high *= 65;  

  float maxVal = max(low, max(mid, max(high, 0.0001)));  

  float r = map(low / maxVal, 0, 1, 50, 255);
  float g = map(mid / maxVal, 0, 1, 50, 255);
  float b = map(high / maxVal, 0, 1, 50, 255);

  return color(r, g, b);
}

float fitnessFunction(PVector pos) {
  return pos.x * pos.x + pos.y * pos.y;
}
  
class Particle {
  PVector position, velocity, bestPosition;
  float bestValue, size, speed, saturation, lifespan;
  color particleColor;
  
  Particle(PVector startPos) {
    position = startPos.copy();
    velocity = PVector.random2D().mult(random(1, 5)); // Random initial push
    lifespan = 255; // Fades over time
    //position = new PVector(random(width), random(height));
    //velocity = new PVector(random(-2, 2), random(-2, 2));
    bestPosition = position.copy();
    bestValue = fitnessFunction(position);
    size = random(15, 30); // Start smaller!
    speed = 1;

    
    if (bestValue < globalBestVal) {
      globalBestVal = bestValue;
      globalBestPos = bestPosition.copy();
    }
  }
  
void update() {
  position.add(velocity);
  lifespan -= 1.5; // Gradual fade out
  if (lifespan <= 0) {
    activeParticles.remove(this);  // Remove faded particles
}
  
  
  
  // Slow down explosion over time
  velocity.mult(0.5);  // Gradual slowdown to transition into swarm movement

  if (velocity.mag() < 1) {  // Once explosion slows down, switch to swarm behavior
  float w = 0.5;
  float c1 = 1.5;
  float c2 = 1.5;
  
  float volume = amp.analyze() * 10;
  float pitch = pitchDetector.analyze();  // Returns the detected pitch
  float targetSize = constrain(map(volume, 0, 1, 10, 50), 0.5, 85); // Allows shrinking and growing
  
   // Ensure pitch is valid before using it
  if (pitch > 50 && pitch < 1000) {  // Ignore out-of-range or zero values
    float mappedSpeed = map(pitch, 50, 1000, 0.5, 5);  // Scale pitch to reasonable speeds
    speed = lerp(speed, mappedSpeed, 0.1);
  } 
  
  
  size = lerp(size, targetSize, 0.1); // Smooth transition instead of instant change
  updateColor(spectrum); // Call color update function
  
  PVector rp = PVector.random2D().mult(c1 * 0.1); // Scaled down influence
  PVector rg = PVector.random2D().mult(c2 * 0.1);
  
  PVector cognitive = PVector.sub(bestPosition, position).mult(rp.x);
  PVector social = PVector.sub(globalBestPos, position).mult(rg.x);
  
  velocity.mult(w).add(cognitive).add(social).mult(speed);
  velocity.limit(5); // Cap velocity to prevent crazy movement
  position.add(velocity);
  }
  
  // Bounce off screen edges
  if (position.x < 0 || position.x > width) velocity.x *= -0.5;
  if (position.y < 0 || position.y > height) velocity.y *= -0.5;
  
  float currentFitness = fitnessFunction(position);
  if (currentFitness < bestValue) {
    bestValue = currentFitness;
    bestPosition = position.copy();
  }
  
  if (bestValue < globalBestVal) {
    globalBestVal = bestValue;
    globalBestPos = bestPosition.copy();
  }
}

  
  void display() {
    fill(particleColor, lifespan);
    noStroke();
    ellipse(position.x, position.y, size, size);
  }
  
  void updateColor(float[] spectrum) {
  int maxIndex = spectrum.length - 1;

  float low = (spectrum[min(0, maxIndex)] + spectrum[min(1, maxIndex)] + spectrum[min(2, maxIndex)]) / 3;
  float mid = (spectrum[min(8, maxIndex)] + spectrum[min(9, maxIndex)] + spectrum[min(10, maxIndex)]) / 3;
  float high = (spectrum[min(18, maxIndex)] + spectrum[min(19, maxIndex)] + spectrum[min(20, maxIndex)]) / 3;

  mid *= 17;  // Boost mid frequencies (green)
  high *= 65; // Boost high frequencies (blue)

  float maxVal = max(low, max(mid, max(high, 0.0001))); 

  float r = map(low / maxVal, 0, 1, 50, 255);
  float g = map(mid / maxVal, 0, 1, 50, 255);
  float b = map(high / maxVal, 0, 1, 50, 255);

  particleColor = lerpColor(particleColor, color(r, g, b), 0.1);
}
}
