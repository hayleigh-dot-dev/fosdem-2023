import { Some } from "../gleam_stdlib/gleam/option.mjs";

export const resume = (ctx) => ctx.resume();
export const suspend = (ctx) => ctx.suspend();

export const create_from_patch = (ctx, patch) => {
  // I'd like to use a `switch` here on the patch's constructor to determine
  // which variant it is, but a minifying bundler will go ahead and rename those
  // constructors to something nonsense.
  //
  // Instead we're doing some sort of cursed structural pattern matching here and
  // relying on the fields disjoint between all patches.
  if ("t" in patch && "params" in patch) {
    create_node(ctx, patch);
  }

  if ("name" in patch && "value" in patch) {
    create_param(ctx, patch);
  }

  if ("from" in patch && "to" in patch) {
    connect(ctx, patch);
  }
};

const create_node = (ctx, { key, t, params }) => {
  params = params.toArray();

  const node = (ctx.nodes[key] = (() => {
    switch (t) {
      case "OscillatorNode":
        return ctx.createOscillator();
      case "DelayNode":
        return ctx.createDelay(1);
      case "BiquadFilterNode":
        return ctx.createBiquadFilter();
      case "GainNode":
        return ctx.createGain();
      case "AudioDestinationNode":
        return ctx.destination;
      default: {
        console.warn(
          `AudioNodes of type ${t} are not currently supported.`,
          `Please consider opening a PR if you"re interested in adding support for this node.`,
          `Creating a dummy gain node instead.`
        );
        return ctx.createGain();
      }
    }
  })());

  node.start?.();
  params.forEach((param) => create_param(ctx, { key, ...param }));

  return node;
};

const create_param = (ctx, { key, name, value }) => {
  if (ctx.nodes[key][name] instanceof window.AudioParam) {
    ctx.nodes[key][name].value = value;
  } else {
    ctx.nodes[key][name] = value;
  }
};

const connect = (ctx, { from, to, param }) => {
  if (param instanceof Some) {
    ctx.nodes[from].connect(ctx.nodes[to][param[0]]);
  } else {
    ctx.nodes[from].connect(ctx.nodes[to]);
  }
};

export const delete_from_patch = (ctx, patch) => {
  // like with `create_from_patch` we can't rely on using the `constructor`
  // and instead need to do some structural duck typing shenanigans. The shape
  // of things is slightly different for deletions.
  if ("name" in patch) {
    delete_param(ctx, patch);
  }

  if ("from" in patch && "to" in patch) {
    disconnect(ctx, patch);
  }

  if ("key" in patch) {
    delete_node(ctx, patch);
  }
};

const delete_node = (ctx, { key }) => {
  ctx.nodes[key].stop?.();
  ctx.nodes[key].disconnect();

  delete ctx.nodes[key];
};

const delete_param = (ctx, { key, name }) => {
  if (ctx.nodes[key][name] instanceof window.AudioParam) {
    ctx.nodes[key][name].value = ctx.nodes[key][name].defaultValue;
  }
};

const disconnect = (ctx, { from, to, param }) => {
  if (param instanceof Some) {
    ctx.nodes[from].disconnect(ctx.nodes[to][param[0]]);
  } else {
    ctx.nodes[from].disconnect(ctx.nodes[to]);
  }
};
