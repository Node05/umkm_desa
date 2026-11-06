const express = require("express");
const { Pool } = require("pg");
require("dotenv").config();

const app = express();
app.use(express.json());

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

// 1. POST - Tambah Kategori
app.post("/categories", async (req, res) => {
  try {
    const { name, slug, description } = req.body;
    const result = await pool.query(
      "INSERT INTO categories (name, slug, description) VALUES ($1, $2, $3) RETURNING *",
      [name, slug, description],
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 2. GET - Ambil Semua Kategori
app.get("/categories", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM categories");
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 3. GET - Ambil Kategori by ID
app.get("/categories/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query("SELECT * FROM categories WHERE id = $1", [
      id,
    ]);
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 4. PUT - Update Kategori
app.put("/categories/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { name, slug, description } = req.body;
    const result = await pool.query(
      "UPDATE categories SET name = $1, slug = $2, description = $3 WHERE id = $4 RETURNING *",
      [name, slug, description, id],
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 5. DELETE - Hapus Kategori
app.delete("/categories/:id", async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query("DELETE FROM categories WHERE id = $1", [id]);
    res.json({ message: "Kategori berhasil dihapus" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(3000, () => {
  console.log("Server E-Commerce UMKM berjalan di port 3000");
});
