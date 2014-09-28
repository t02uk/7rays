__DEBUG__ = false

class God
  @setup: ->
    @deviceWidth = 640.0
    @deviceHeight = 480.0
    @scene = new THREE.Scene()
    @scene.fog = new THREE.FogExp2(0x000000, 0.03)
    @camera = new THREE.PerspectiveCamera(90, @deviceWidth / @deviceHeight, Math.pow(0.1, 8), Math.pow(10, 3))
    @renderer = new THREE.WebGLRenderer(antialias: true)
    #@renderer.setFaceCulling("front_and_back")
    @renderer.setSize(@deviceWidth, @deviceHeight)
    c = document.getElementById('c')
    c.appendChild(@renderer.domElement)

    @rays = for i in [0 .. 7]
      new Ray(@scene, i)
    @target = new Target(@scene, x: 0, y: 0, z: 0)
    @cameraControll = new CameraControll(@camera)

    @particleManager = new ParticleManager()

  @start: ->
    render = =>
      @camera.position.z = 5
      @target.update()
      @cameraControll.update()
      for ray in @rays
        ray.update()
      @particleManager.update()
      requestAnimationFrame(render)
      @renderer.render(@scene, @camera)
    render()

class CameraControll
  constructor: (@camera) ->
    @lookAt = new THREE.Vector3(0, 0, 0)
    @count = 0
  update: ->
    pTarget = God.rays[0].position()
    @pTarget = new THREE.Vector3(
      Math.sin(@count * 0.022) * 15,
      Math.cos(@count * 0.034) * 15,
      Math.sin(@count * 0.026) * 15
    )
    @lTarget = new THREE.Vector3(
      Math.sin(@count * 0.021) * 5,
      Math.cos(@count * 0.031) * 5,
      Math.sin(@count * 0.016) * 5
    )

    @camera.position.x = (@camera.position.x * 8 + @pTarget.x * 3) / 10
    @camera.position.y = (@camera.position.y * 8 + @pTarget.y * 3) / 10
    @camera.position.z = (@camera.position.z * 8 + @pTarget.z * 3) / 10
    @lookAt.x = (@lookAt.x * 8 + @lTarget.x * 2) / 10
    @lookAt.y = (@lookAt.y * 8 + @lTarget.y * 2) / 10
    @lookAt.z = (@lookAt.z * 8 + @lTarget.z * 2) / 10

    @camera.lookAt(@lookAt)

    @count++

  perspectiveVector: ->
    s = God.target.position.clone()
    s.sub(@camera.position).normalize()

class Target
  @material: new THREE.MeshBasicMaterial
    color: 0x111155
    transparent: true
    depthTest: false
    blending: THREE.AdditiveBlending
    side: THREE.DoubleSide

  constructor: (@scene, p) ->
    @count = 0
    @speed = new THREE.Vector3(0.0, 0.0, 0.0)
    @geometry = new THREE.BoxGeometry(1.0, 1.0, 1.0)
    @mesh = new THREE.Mesh(@geometry, Target.material)
    @position = @mesh.position
    @goalPos = @position.clone()

    @scene.add(@mesh) if __DEBUG__

  update: ->
    diff = @goalPos.clone()
    diff.sub(@position)
    len = diff.length()
    if @count % 1000 is 0 or len < 1
      @goalPos.x = 20.0 * Math.random() - 10
      @goalPos.y = 20.0 * Math.random() - 10
      @goalPos.z = 20.0 * Math.random() - 10

    diff.normalize()
    diff.multiplyScalar(0.1)
  
    @speed.add(diff)
    @speed.multiplyScalar(0.95)

    @position.add(@speed)

    @count++


class Ray
  class Bone
    constructor: (@index, p) ->
      @position = new THREE.Vector3(p.x, p.y, p.z)
      @direction = new THREE.Vector3()

  constructor: (@scene, @nth) ->
    @speed = new THREE.Vector3(0, 0.1, 0)

    m = 24
    p = 
      x: Math.random()
      y: Math.random()
      z: Math.random()
    @bones = for index in [0 ... m]
      new Bone(index, p)

    @geometry = new THREE.Geometry()
    for v, i in @bones
      @geometry.vertices.push(
        new THREE.Vector3(-1, i, 0),
        new THREE.Vector3( 1, i, 0)
      )
    for i in [0 ... m - 1]
      vi = i * 2
      @geometry.faces.push(
        new THREE.Face3(vi    , vi + 1, vi + 2),
        new THREE.Face3(vi + 1, vi + 3, vi + 2)
      )
      @geometry.faceVertexUvs[0].push([
        new THREE.Vector2(1.0, 0.0)
        new THREE.Vector2(0.0, 0.0),
        new THREE.Vector2(1.0, 1.0),
        ], [
        new THREE.Vector2(0.0, 0.0),
        new THREE.Vector2(0.0, 1.0)
        new THREE.Vector2(1.0, 1.0),
      ])

    color = new THREE.Color()
    color.setHSL(@hue(), 1.0, 0.7)
    @material = new THREE.MeshBasicMaterial
      color: color
      map: @makeTexture()
      side: THREE.DoubleSide
      blending: THREE.AdditiveBlending
      transparent: true
    @mesh = new THREE.Mesh(@geometry, @material)
    @scene.add(@mesh)
  
  hue: ->
    1.0 * @nth / 7
  makeTexture: ->
    unless @texture
      @canvas = document.createElement('canvas')
      width = @canvas.width = 32
      height = @canvas.height = 32
      ctx = @canvas.getContext('2d')
      grad = ctx.createLinearGradient(0, 0, width, 0)
      grad.addColorStop(0, 'rgb(0, 0, 0)')
      grad.addColorStop(0.5, 'rgb(255, 255, 255)')
      grad.addColorStop(1, 'rgb(0, 0, 0)')
      ctx.fillStyle = grad
      ctx.beginPath()
      ctx.rect(0, 0, width, height)
      ctx.fill()
      @texture = THREE.ImageUtils.loadTexture(@canvas.toDataURL())
      document.body.appendChild(@canvas) if __DEBUG__
    @texture

  position: ->
    @bones[0].position

  update: ->
    target = God.target
    diff = target.position.clone()
    diff.sub(@position())
    diff.multiplyScalar(0.35 - 0.04 * @nth)
    
    @speed.add(diff)
    @speed.multiplyScalar(0.99 - 0.005 * @nth)
    
    for n in [@bones.length - 1 .. 1]
      @bones[n].position.copy(@bones[n - 1].position)
      @bones[n].direction.copy(@bones[n - 1].direction)

    @bones[0].position.add(@speed)
    direction = @speed.clone()
    direction.normalize()
    @bones[0].direction = direction

    pv = God.cameraControll.perspectiveVector()
    
    for bone, i in @bones
      i = bone.index
      p = bone.position
      d = bone.direction
      s = new THREE.Vector3()
      s.crossVectors(pv, d)
      w = Math.sin(1.0 * i / @bones.length * Math.PI * 2) * 0.1
      s.multiplyScalar(w)
      @geometry.vertices[i * 2 + 0].set(p.x + s.x, p.y + s.y, p.z + s.z)
      @geometry.vertices[i * 2 + 1].set(p.x - s.x, p.y - s.y, p.z - s.z)

    # particle
    for i in [0 .. @bones.length - 1]
      if Math.random() * i > 12.0 and Math.random() < 0.8
        bone = @bones[i]
        speed = new THREE.Vector3(
          Math.random() * 0.2 - 0.4,
          Math.random() * 0.2 - 0.4,
          Math.random() * 0.2 - 0.4
        )
        speed.add(@speed.clone().multiplyScalar(-0.25))
        God.particleManager.add(@scene, @hue(), bone.position, speed)
    @geometry.verticesNeedUpdate = true


class ParticleManager
  constructor: ->
    @particles = []
  update: ->
    for particle in @particles
      if particle.alloced()
        particle.update()
        if particle.speed.lengthSq() < 0.1 or particle.count > 50
          @free(particle)

  add: (@scene, hue, position, speed) ->
    for particle in @particles
      if not particle.alloced() and particle.hue is hue
        particle.alloc(position, speed)
        return particle
    # not found
    @particles.push(new Particle(@scene, hue, position, speed))

  free: (particle) ->
    for otherParticle in @particles
      if particle.eq(otherParticle)
        particle.free()

class Particle
  @materialMemo: {}
  @_id: 0
  constructor: (@scene, @hue, position, speed) ->
    @material = @retrieveMaterial(hue)
    @mesh = new THREE.Sprite(@material)
    @id = Particle._id++
    @alloc(position, speed)
    @scene.add(@mesh)
  eq: (that) ->
    this.id is that.id
  alloc: (position, speed) ->
    @count = 0
    @position = position.clone()
    @speed = speed.clone()
    @mesh.visible = true
  free: ->
    @mesh.visible = false
  alloced: ->
    @mesh.visible

  position: ->
    @mesh.position
  update: ->
    @speed.multiplyScalar(0.98)
    @position.add(@speed)
    @mesh.position.copy(@position)
    size = @speed.length()
    @mesh.scale.set(size, size, size)
    @count++
    
  retrieveMaterial: (hue) ->
    key = "#{hue}"
    unless Particle.materialMemo[key]
      color = new THREE.Color()
      color.setHSL(hue, 0.5, 0.5)
      @material = new THREE.SpriteMaterial
        map: @makeTexture()
        color: color
        transparent: true
        blending: THREE.AdditiveBlending
      Particle.materialMemo[key] = @material
    Particle.materialMemo[key]

  makeTexture: ->
    unless @texture
      @canvas = document.createElement('canvas')
      width = @canvas.width = 64
      height = @canvas.height = 64
      ctx = @canvas.getContext('2d')
      grad = ctx.createRadialGradient(0.5 * width, 0.5 * height, 0.05 * width, 0.5 * width, height * 0.5, 0.5 * width)
      grad.addColorStop(0, 'rgb(255, 255, 255)')
      grad.addColorStop(0.4, 'rgb(255, 255, 255)')
      grad.addColorStop(1, 'rgb(0, 0, 0)')
      ctx.fillStyle = grad
      ctx.beginPath()
      ctx.rect(0, 0, width, height)
      ctx.fill()
      @texture = THREE.ImageUtils.loadTexture(@canvas.toDataURL())
      document.body.appendChild(@canvas) if __DEBUG__
    @texture


window.God = God
