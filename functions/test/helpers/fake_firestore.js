/**
 * テストで使う分だけを真似た、メモリ上の Firestore
 */
class FakeFirestore {
  constructor() {
    this.docs = new Map();
    this.nextId = 1;
  }

  _ref(path) {
    const store = this;
    return {
      id: path.split('/').pop(),
      path,
      async get() {
        const data = store.docs.get(path);
        return { exists: data !== undefined, data: () => data };
      },
      async set(data, options = {}) {
        store.docs.set(path, options.merge ? { ...(store.docs.get(path) || {}), ...data } : { ...data });
      },
      async update(data) {
        if (!store.docs.has(path)) throw new Error(`no document: ${path}`);
        store.docs.set(path, { ...store.docs.get(path), ...data });
      },
    };
  }

  doc(path) {
    return this._ref(path);
  }

  collection(name) {
    const store = this;
    return {
      doc: (id) => store._ref(`${name}/${id || `auto${store.nextId++}`}`),
      async get() {
        const docs = [...store.docs.entries()]
          .filter(([path]) => path.startsWith(`${name}/`) && path.split('/').length === 2)
          .map(([path, data]) => ({ id: path.split('/').pop(), data: () => data }));
        return { docs };
      },
      where: (field, op, value) => ({
        async get() {
          const docs = [...store.docs.entries()]
            .filter(([path, data]) => path.startsWith(`${name}/`) && data[field] === value)
            .map(([path, data]) => ({ id: path.split('/').pop(), data: () => data }));
          return { docs };
        },
      }),
    };
  }

  batch() {
    const ops = [];
    return {
      set: (ref, data) => ops.push(() => this.docs.set(ref.path, { ...data })),
      update: (ref, data) => ops.push(() => this.docs.set(ref.path, { ...this.docs.get(ref.path), ...data })),
      commit: async () => ops.forEach((op) => op()),
    };
  }

  clouds() {
    return [...this.docs.entries()].filter(([p]) => p.startsWith('clouds/')).map(([, d]) => d);
  }
}

module.exports = FakeFirestore;
