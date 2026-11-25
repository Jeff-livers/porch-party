const MANIFEST_URL = 'clips/clips.json';
const MUSIC_URL = 'audio/song.m4a';
const GRAIN_TILE_SIZE = 128;
const MUSIC_DISPLAY = {
  idle: { icon: '▶︎', label: 'TAP FOR SOUND' },
  playing: { icon: '▶︎', label: 'SOUND ON' },
  paused: { icon: '❚❚', label: 'PAUSED' },
};

const footage = document.querySelector('.footage');
const videos = [...footage.querySelectorAll('video')];
const musicButton = document.querySelector('.osd');
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

drawGrainTile();
startFootage();
setUpMusic();

function setUpMusic() {
  const music = new Audio();
  music.preload = 'none';
  music.loop = true;

  const showMusicState = (state) => {
    const { icon, label } = MUSIC_DISPLAY[state];
    musicButton.dataset.state = state;
    musicButton.querySelector('.osd-icon').textContent = icon;
    musicButton.querySelector('.osd-label').textContent = label;
  };

  music.addEventListener('playing', () => showMusicState('playing'));
  music.addEventListener('pause', () => showMusicState('paused'));

  document.addEventListener('click', () => {
    if (!music.getAttribute('src')) music.src = MUSIC_URL;
    if (music.paused) {
      music.play().catch(() => showMusicState(music.currentTime > 0 ? 'paused' : 'idle'));
    } else {
      music.pause();
    }
  });
}

async function startFootage() {
  let clips;
  try {
    const response = await fetch(MANIFEST_URL, { cache: 'no-cache' });
    clips = (await response.json()).clips;
  } catch {
    return;
  }
  if (!Array.isArray(clips) || clips.length === 0) return;

  if (prefersReducedMotion) showStillFrame(clips);
  else playShuffledClips(clips);
}

async function showStillFrame(clips) {
  const [video] = videos;
  video.src = clips[Math.floor(Math.random() * clips.length)];
  video.classList.add('is-active');
  try {
    const firstFrameShown = nextFrameShown(video);
    await video.play();
    await firstFrameShown;
    video.pause();
    footage.classList.add('is-live');
  } catch {}
}

function playShuffledClips(clips) {
  const nextClip = shuffledCycle(clips);
  const maxConsecutiveFailures = clips.length * 2;
  let [active, upcoming] = videos;
  let consecutiveFailures = 0;

  if (clips.length === 1) {
    active.loop = true;
  } else {
    for (const video of videos) {
      video.addEventListener('ended', () => video === active && cutToUpcoming());
    }
  }

  for (const video of videos) {
    video.addEventListener('error', () => {
      if (++consecutiveFailures > maxConsecutiveFailures) return;
      if (video === upcoming) loadNextClipInto(upcoming);
      else cutToUpcoming();
    });
  }

  loadNextClipInto(active);
  if (clips.length > 1) loadNextClipInto(upcoming);
  playAndBringToFront(active);

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && active.paused && !active.ended && active.currentSrc) {
      active.play().catch(() => {});
    }
  });

  async function cutToUpcoming() {
    [active, upcoming] = [upcoming, active];
    if (await playAndBringToFront(active)) loadNextClipInto(upcoming);
  }

  function loadNextClipInto(video) {
    video.src = nextClip();
    video.load();
  }

  async function playAndBringToFront(video) {
    const firstFrameShown = nextFrameShown(video);
    try {
      await video.play();
    } catch (error) {
      if (error.name === 'NotAllowedError') {
        document.addEventListener('click', () => {
          for (const v of videos) if (v !== video) unlockForLaterPlayback(v);
          playAndBringToFront(video);
        }, { once: true });
      }
      return false;
    }
    await firstFrameShown;
    for (const v of videos) v.classList.toggle('is-active', v === video);
    footage.classList.add('is-live');
    consecutiveFailures = 0;
    return true;
  }
}

function unlockForLaterPlayback(video) {
  video.play().then(() => {
    video.pause();
    video.currentTime = 0;
  }).catch(() => {});
}

function nextFrameShown(video) {
  return new Promise((resolve) => {
    video.addEventListener('timeupdate', resolve, { once: true });
    video.requestVideoFrameCallback?.(() => resolve());
  });
}

function shuffledCycle(items) {
  let remaining = [];
  let previous;
  return () => {
    if (remaining.length === 0) {
      remaining = shuffle([...items]);
      const last = remaining.length - 1;
      if (last > 0 && remaining[last] === previous) {
        [remaining[0], remaining[last]] = [remaining[last], remaining[0]];
      }
    }
    previous = remaining.pop();
    return previous;
  };
}

function shuffle(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
  return array;
}

function drawGrainTile() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = GRAIN_TILE_SIZE;
  const context = canvas.getContext('2d');
  const image = context.createImageData(GRAIN_TILE_SIZE, GRAIN_TILE_SIZE);
  const pixels = image.data;
  for (let i = 0; i < pixels.length; i += 4) {
    const shade = Math.random() < 0.5 ? 0 : 255;
    pixels[i] = pixels[i + 1] = pixels[i + 2] = shade;
    pixels[i + 3] = Math.random() * 255;
  }
  context.putImageData(image, 0, 0);
  document.documentElement.style.setProperty('--grain', `url(${canvas.toDataURL()})`);
}
