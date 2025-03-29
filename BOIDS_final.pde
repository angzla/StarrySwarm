import processing.sound.*;

Flock flock;
AudioIn in;
FFT fft;
PitchDetector pitchDetector;
Amplitude amp;
Waveform waveform;
int bands = 32;
float[] spectrum;
boolean isStopped = false;

void setup() {
  fullScreen();
  flock = new Flock();

  // Initialize Sound library components
  in = new AudioIn(this, 0);
  in.start();

  fft = new FFT(this, bands);
  fft.input(in);
  spectrum = new float[bands];

  amp = new Amplitude(this);
  amp.input(in);
  
  pitchDetector = new PitchDetector(this);
  pitchDetector.input(in);  // Connect input
  
  waveform = new Waveform(this, 100); //100 is the number of samples you want read at a time
  waveform.input(in);

  // Start with some boids
  for (int i = 0; i < 100; i++) {
    flock.addBoid(new Boid(random(width), random(height)));
  }
}

void draw() {
  background(0);
  
  // Analyze audio
  fft.analyze(spectrum);
  float volume = amp.analyze() * 10;
  
  // Get pitch in Hz
  float pitchHZ = pitchDetector.analyze();  // Returns the detected pitch
  println("Pitch HZ:", pitchHZ);
  
  //get waveform 
  //waveform.analyze();
  
int MAX_BOIDS = 2000;

  flock.modifyBehavior(volume, pitchHZ); 

  // Influence boid behavior based on frequency bands
  flock.run(spectrum, pitchHZ);
  
  for (int i = 0; i < spectrum.length; i++) {
  println("Spectrum[" + i + "]: " + spectrum[i]);
}

  if (!isStopped && volume > 0.3) {
    int numToAdd = int(random(volume, volume * 50)); // Randomize count
    for (int i = 0; i < numToAdd; i++) {
      if (flock.boids.size() < MAX_BOIDS) {
        flock.addBoid(new Boid(random(width), random(height)));
      }
    }
  }

  // Control flock behavior
  if (!isStopped) {
    flock.modifyBehavior(volume, pitchHZ);
    flock.run(spectrum, pitchHZ);
  } else {
    flock.freeze(); // Merge particles into one solid shape
  }
}

// Toggle freeze state with a key press
void keyPressed() {
  if (key == ' ') {  // Press SPACE to toggle stop/start
    isStopped = !isStopped;
  }
}

// The Flock class
class Flock {
  ArrayList<Boid> boids;

  Flock() {
    boids = new ArrayList<Boid>();
  }

  void run(float[] spectrum, float pitchHZ) {
    for (Boid b : boids) {
      b.run(boids, spectrum, pitchHZ);
    }
  }

  void addBoid(Boid b) {
    boids.add(b);
  }
  
  void modifyBehavior(float volume, float pitchHZ) {
  for (Boid b : flock.boids) {
    float speedFactor = map(volume, 0, 1, 1, 10);
    float directionFactor = map(pitchHZ, 20, 2000, -1, 1);
    
    b.maxspeed = speedFactor;
    b.maxforce = speedFactor * 0.02;
    
    // If pitch changes suddenly, boids will scatter
    if (abs(pitchHZ - b.lastPitch) > 100) {
      b.velocity.rotate(directionFactor * HALF_PI);  // Rotate based on pitch shifts
    }
    
    b.lastPitch = pitchHZ;
  }
}


void freeze() {
  for (Boid b : boids) {
      b.velocity.set(0, 0);
      b.acceleration.set(0, 0);
    
    // Draw trail with fading effect
    for (int i = 0; i < b.trail.size(); i++) {
      PVector pos = b.trail.get(i);
      
      // Map alpha from 50 (faded) to 255 (full opacity) based on position in trail
      float alpha = map(i, 0, b.trail.size() - 1, 50, 150);
      fill(b.particleColor, alpha);
      noStroke();
      ellipse(pos.x, pos.y, b.r * 2, b.r * 2);
    }
    
  }
  
}


}

// The Boid class
class Boid {
  PVector position, velocity, acceleration;
  float r, maxforce, maxspeed;
  color particleColor;
  float lastPitch;
  ArrayList<PVector> trail; // Store past positions for the trail
  int trailLength = 30; // Number of positions to store

  Boid(float x, float y) {
    acceleration = new PVector(0, 0);
    float angle = random(TWO_PI);
    velocity = new PVector(cos(angle), sin(angle));
    position = new PVector(x, y);
    r = 6.0;
    maxspeed = 2;
    maxforce = 0.03;
    
    particleColor = color(255); // Default white
    
    lastPitch = 0;
    trail = new ArrayList<PVector>(); // Initialize trail
  }

  void run(ArrayList<Boid> boids, float[] spectrum, float pitchHZ) {
    flock(boids, spectrum, pitchHZ);
    
    // Get high frequency energy
    update(pitchHZ);
    updateColor(spectrum);
    borders();
    render();
  }

  void applyForce(PVector force, float pitchHZ) {
    float pitchFactor = map(pitchHZ, 20, 20000, 0.5, 2); // Scale force
    force.mult(pitchFactor);
    acceleration.add(force);
  }

  void flock(ArrayList<Boid> boids, float[] spectrum, float pitchHZ) {
    PVector sep = separate(boids);
    PVector ali = align(boids);
    PVector coh = cohesion(boids);

    // Influence forces based on frequency spectrum
    float bass = spectrum[0] * 10; // Low frequencies affect separation
    float mid = spectrum[10] * 5;  // Mid frequencies affect alignment
    float high = spectrum[20] * 3; // High frequencies affect cohesion

    sep.mult(1.5 + bass);
    ali.mult(1.0 + mid);
    coh.mult(1.0 + high);

    applyForce(sep, pitchHZ);
    applyForce(ali, pitchHZ);
    applyForce(coh, pitchHZ);
  }

  void update(float pitchHZ) {
    velocity.add(acceleration);
    
    // Ensure pitch is valid before using it
    if (pitchHZ > 0) {
      // Increase speed dynamically with music
        float speedBoost = map(pitchHZ, 20, 20000, 1, 8);
        maxspeed = constrain(speedBoost, 1, 10); // Keep within a reasonable range
        velocity.mult(1 + (maxspeed / 10)); // Scale velocity directly
    }

    velocity.limit(maxspeed);
    position.add(velocity);
    acceleration.mult(0);
    
    // Only add new trail points when moving
    if (!isStopped) {
        trail.add(position.copy());
        if (trail.size() > trailLength) {
            trail.remove(0); // Remove old positions when moving
        }
    }
    
  }

void updateColor(float[] spectrum) {
    if (isStopped) return;
    
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

    // Add an occasional color reset on volume spikes
    if (amp.analyze() > 0.5) {
        particleColor = color(random(255), random(255), random(255));
    }
}

  
  void render() {
    if (isStopped) return; 
  
    noStroke();
    fill(particleColor, 200);
    ellipse(position.x, position.y, r * 3, r * 3);
    
    pushMatrix();
    translate(position.x, position.y);
    rotate(velocity.heading() + radians(90));
  
    popMatrix();

}


  void borders() {
    if (position.x < -r) position.x = width + r;
    if (position.y < -r) position.y = height + r;
    if (position.x > width + r) position.x = -r;
    if (position.y > height + r) position.y = -r;
  }

  PVector separate(ArrayList<Boid> boids) {
    float desiredSeparation = 25.0;
    PVector steer = new PVector(0, 0);
    int count = 0;
    for (Boid other : boids) {
      float d = PVector.dist(position, other.position);
      if ((d > 0) && (d < desiredSeparation)) {
        PVector diff = PVector.sub(position, other.position);
        diff.normalize();
        diff.div(d);
        steer.add(diff);
        count++;
      }
    }
    if (count > 0) steer.div(count);
    if (steer.mag() > 0) {
      steer.normalize();
      steer.mult(maxspeed);
      steer.sub(velocity);
      steer.limit(maxforce);
    }
    return steer;
  }

  PVector align(ArrayList<Boid> boids) {
    float neighborDist = 50;
    PVector sum = new PVector(0, 0);
    int count = 0;
    for (Boid other : boids) {
      float d = PVector.dist(position, other.position);
      if ((d > 0) && (d < neighborDist)) {
        sum.add(other.velocity);
        count++;
      }
    }
    if (count > 0) {
      sum.div(count);
      sum.normalize();
      sum.mult(maxspeed);
      PVector steer = PVector.sub(sum, velocity);
      steer.limit(maxforce);
      return steer;
    }
    return new PVector(0, 0);
  }

  PVector cohesion(ArrayList<Boid> boids) {
    float neighborDist = 50;
    PVector sum = new PVector(0, 0);
    int count = 0;
    for (Boid other : boids) {
      float d = PVector.dist(position, other.position);
      if ((d > 0) && (d < neighborDist)) {
        sum.add(other.position);
        count++;
      }
    }
    if (count > 0) {
      sum.div(count);
      return seek(sum);
    }
    return new PVector(0, 0);
  }

  PVector seek(PVector target) {
    PVector desired = PVector.sub(target, position);
    desired.normalize();
    desired.mult(maxspeed);
    PVector steer = PVector.sub(desired, velocity);
    steer.limit(maxforce);
    return steer;
  }
}
