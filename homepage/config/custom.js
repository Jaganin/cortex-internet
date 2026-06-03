// Debug: log information-widgets structure
setTimeout(() => {
  const el = document.getElementById('information-widgets');
  if (el) {
    console.log('information-widgets found, children:', el.children.length, 'computed display:', getComputedStyle(el).display);
    console.log('HTML:', el.outerHTML.substring(0, 500));
  } else {
    console.log('information-widgets NOT FOUND');
    // Log all IDs
    document.querySelectorAll('[id]').forEach(e => console.log('ID:', e.id, 'tag:', e.tagName));
  }
}, 3000);
