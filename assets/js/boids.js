// Boids flocking simulation background using boids library
import Boids from 'boids';

class BoidsBackground {
  constructor() {
    this.canvas = document.createElement('canvas');
    this.canvas.id = 'boids-canvas';
    this.canvas.style.position = 'fixed';
    this.canvas.style.top = '0';
    this.canvas.style.left = '0';
    this.canvas.style.width = '100%';
    this.canvas.style.height = '100%';
    this.canvas.style.pointerEvents = 'none';
    this.canvas.style.zIndex = '0';
    document.body.prepend(this.canvas);

    this.ctx = this.canvas.getContext('2d');
    this.resize();

    // Initialize boids - random wandering particles
    this.boids = new Boids({
      boids: 400,
      speedLimit: 0.8,
      accelerationLimit: 0.2,
      separationDistance: 25,
      alignmentDistance: 100,
      choesionDistance: 5,
      separationForce: 0.3,
      alignmentForce: 0.5,
      choesionForce: 0.001
    });

    // Initialize positions with slower initial velocity
    for (let i = 0; i < this.boids.boids.length; i++) {
      this.boids.boids[i][0] = Math.random() * this.canvas.width;
      this.boids.boids[i][1] = Math.random() * this.canvas.height;
      this.boids.boids[i][2] = (Math.random() * 0.4 - 0.2);
      this.boids.boids[i][3] = (Math.random() * 0.4 - 0.2);
    }

    window.addEventListener('resize', () => this.resize());
    this.animate();
  }

  resize() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
  }

  draw() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    const boidList = this.boids.boids;

    // Draw boids as small dots (no connections)
    this.ctx.fillStyle = '#8b949e';
    this.ctx.globalAlpha = 0.25;
    for (let boid of boidList) {
      this.ctx.beginPath();
      this.ctx.arc(boid[0], boid[1], 2, 0, Math.PI * 2);
      this.ctx.fill();
    }
    this.ctx.globalAlpha = 1;
  }

  animate() {
    this.boids.tick();

    // Handle edge wrapping
    for (let boid of this.boids.boids) {
      if (boid[0] > this.canvas.width) boid[0] = 0;
      else if (boid[0] < 0) boid[0] = this.canvas.width;
      if (boid[1] > this.canvas.height) boid[1] = 0;
      else if (boid[1] < 0) boid[1] = this.canvas.height;
    }

    this.draw();
    requestAnimationFrame(() => this.animate());
  }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    new BoidsBackground();
  });
} else {
  new BoidsBackground();
}

export default BoidsBackground;

