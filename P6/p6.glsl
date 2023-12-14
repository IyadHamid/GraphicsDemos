#ifdef VS 
 

// Read comments in fragment shader

precision highp float;
attribute vec3 position;
attribute vec3 normal;
uniform mat3 normalMatrix;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
varying vec3 fNormal;
varying vec3 fPosition;

// vvvvvvvvvvv modifiable variables vvvvvvvvvvv //

// magnitude of offset to add (note that this does not effect fNormal)
const float random_magnitude = 0.02;

// enable/disable features
const bool add_random = true;

// ^^^^^^^^^^^ modifiable variables ^^^^^^^^^^^ //

vec3 fastNoise(vec3 x) {
  // lazily-made white noise ranges the box (0,0,0) -> (1,1,1)
  return mod(floor(x*9876543.21), 32.0) / 32.0;
}

void main() {
  fNormal = normalize(normalMatrix * normal);
  vec4 pos = modelViewMatrix * vec4(position, 1.0);
  
  // add randomness to each point of an organic ore look
  // note that this does not effect fNormal and thus fNormal will look like original model.
  pos.xyz += float(add_random) * random_magnitude * (fastNoise(position.xyz) - vec3(0.5));
  
  fPosition = pos.xyz;
  gl_Position = projectionMatrix * pos;
}
 
#else 
 
#extension GL_OES_standard_derivatives : enable

// Made by Iyad Hamid

// This shows an emerald-geodesic-like material with 3 lights and ambient occlusion
// The material has easy to edit properties found in the modifable variables section

// Since I was unable to calculate a smooth concavity
// I decided to make the specular non-smoothed to fit the style

precision highp float;
uniform float time;
uniform vec2 resolution;
varying vec3 fPosition;
varying vec3 fNormal;
const vec3 view_dir = vec3(0.0, 0.0, 1.0);

// vvvvvvvvvvv modifiable variables vvvvvvvvvvv //

// color: color (extreme values are emissive)
// diffuse: diffuseness [0,1]
// specular: specularity [0, infty]

// base material
const vec3 base_color = vec3(0.1, 1.0, 0.5);
const float base_diffuse = 0.7;
const float base_specular = 15.0;
// wear material
const vec3 wear_color = vec3(1.0, 1.0, 1.0);
const float wear_diffuse = 0.9;
const float wear_specular = 0.0;

const float wear_amount = 10.0;

// animation speed
const float speed = 20.0;

// camera settings
const float gamma = 1.5;
const float exposure = 1.0;

// enable/disable features
const bool white_light = true;
const bool blue_light = true;
const bool red_light = true;
const bool ambient_occlusion = true;
const bool edge_mask = true;
const bool camera_settings = true;

const bool no_true_normal = false;
const bool no_concavity = false; 

// ^^^^^^^^^^^ modifiable variables ^^^^^^^^^^^ //

vec3 trueNormal() {
  if (no_true_normal)
    return fNormal;
  // calculated normal will be flat (opposed to smoothed) due to lerped fPosition
  vec3 x = normalize(dFdx(fPosition));
  vec3 y = normalize(dFdy(fPosition));
  return vec3(
    dot(-view_dir, x),
    dot(-view_dir, y),
    dot(-view_dir, cross(y, x))
  );
}

float concavity() {
  if (no_concavity)
    return 0.0;
  // calculated by concavity and normalized by position
  // multiplied by a small constant to 'normalize' it
  // this effectively creates an non-normalized edge mask
  return  0.01 * (
    dFdx(fNormal).x / dFdx(fPosition).x +
    dFdy(fNormal).y / dFdy(fPosition).y
  );
}

vec3 alteredPhong(vec3 dir, vec3 color, float roughness, float specular) {
  // this is a blinn-phong reflection material
  // roughness and specular parameters are not physically accurate 
  vec3 reflect_dir = reflect(-dir, trueNormal()); // use specular trueNormal for a geodesic look
  return color * (
    // diffuse
    roughness * dot(fNormal, dir) +
    // specular
    (1.0 - roughness) * pow(max(0.0, dot(view_dir, reflect_dir)), specular) +
    // ambient
    0.1
  );
}

vec3 addLight(vec3 dir, vec3 color) {
  // this adds light to our object's material
  // the material is defined here
  float edge_mask = clamp(concavity() * wear_amount, 0.0, 1.0) * float(edge_mask);
  
  vec3 base_mat = base_color * alteredPhong(dir, color, base_diffuse, base_specular);
  vec3 wear_mat = wear_color * alteredPhong(dir, color, wear_diffuse, wear_specular); 
  
  return mix(base_mat, wear_mat, edge_mask);
}

void main()
{
  
  // ambient occlusion mask
  // use negative concavity (i.e. concave) as AO mask
  float ao_mask = 1.0 - float(ambient_occlusion) * clamp(-concavity() * 1.5, 0.0, 1.0);
  
  // calculate color through the addition of each light (note that the material is defined in addLight)
  vec3 color = (
    float(white_light) * // rotating white light
      addLight(vec3(cos(time * speed), sin(time * speed), 0.5), vec3(1.0,1.0,1.0)) + 
    float(blue_light) * // blue light
      addLight(vec3( 1.0, 1.0, 0.0), vec3(0.05,0.05,0.4)) + 
    float(red_light) * // red light
      addLight(vec3(-1.0, 1.0, 0.0), vec3(0.4,0.05,0.05)) 
  ) * ao_mask;
  
  // gamma correct and apply exposure
  // we should gamma correct as we calculated light through linear space
  if (camera_settings) { // this if branch depends on a constant (no stalling)
    color = pow(color, vec3(1.0/gamma));
    color *= exposure;
  }  
  
  gl_FragColor = vec4(color, 1.0);
}
 
#endif