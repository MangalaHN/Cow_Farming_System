package com.farm;

import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api")
public class ApiController {

    private final JdbcTemplate jdbc;

    public ApiController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // table name, primary key, writable columns (generated columns are excluded)
    record Meta(String table, String pk, List<String> cols) {}

    private static final Map<String, Meta> MODULES = Map.of(
        "cows", new Meta("cow", "cow_id", List.of("cow_name", "breed", "age", "gender", "weight", "registration_date", "health_status")),
        "milk", new Meta("milk_production", "production_id", List.of("cow_id", "production_date", "morning_qty", "evening_qty")),
        "feeding", new Meta("feeding", "feed_id", List.of("cow_id", "feed_type", "feed_quantity", "feeding_date", "feed_cost")),
        "health", new Meta("health_record", "health_id", List.of("cow_id", "disease_details", "treatment", "vaccination_date", "vet_name", "vet_phone")),
        "breeding", new Meta("breeding", "breeding_id", List.of("cow_id", "breeding_date", "pregnancy_status", "expected_delivery_date")),
        "sales", new Meta("milk_sales", "sale_id", List.of("sale_date", "customer_name", "milk_quantity", "price_per_litre")),
        "expenses", new Meta("expense", "expense_id", List.of("expense_category", "expense_description", "expense_date", "amount"))
    );

    private static final Map<String, String> REPORTS = Map.of(
        "daily-milk",
        "SELECT production_date, SUM(total_qty) AS total_litres FROM milk_production GROUP BY production_date ORDER BY production_date DESC",
        "monthly-milk",
        "SELECT DATE_FORMAT(production_date,'%Y-%m') AS month, SUM(total_qty) AS total_litres, ROUND(AVG(total_qty),2) AS avg_per_cow_day FROM milk_production GROUP BY month ORDER BY month DESC",
        "cowwise-milk",
        "SELECT c.cow_id, c.cow_name, COALESCE(SUM(m.total_qty),0) AS total_litres, ROUND(COALESCE(AVG(m.total_qty),0),2) AS avg_per_day FROM cow c LEFT JOIN milk_production m ON c.cow_id=m.cow_id GROUP BY c.cow_id, c.cow_name ORDER BY total_litres DESC",
        "sales-monthly",
        "SELECT DATE_FORMAT(sale_date,'%Y-%m') AS month, SUM(milk_quantity) AS litres_sold, SUM(total_amount) AS revenue FROM milk_sales GROUP BY month ORDER BY month DESC",
        "expenses-monthly",
        "SELECT DATE_FORMAT(expense_date,'%Y-%m') AS month, expense_category, SUM(amount) AS total_amount FROM expense GROUP BY month, expense_category ORDER BY month DESC, total_amount DESC",
        "health-history",
        "SELECT c.cow_name, h.disease_details, h.treatment, h.vaccination_date, h.vet_name FROM health_record h INNER JOIN cow c ON h.cow_id=c.cow_id ORDER BY c.cow_name, h.vaccination_date DESC",
        "feed-consumption",
        "SELECT c.cow_name, f.feed_type, SUM(f.feed_quantity) AS total_kg, SUM(f.feed_cost) AS total_cost FROM feeding f INNER JOIN cow c ON f.cow_id=c.cow_id GROUP BY c.cow_name, f.feed_type ORDER BY c.cow_name"
    );

    private Meta meta(String m) {
        Meta meta = MODULES.get(m);
        if (meta == null) throw new IllegalArgumentException("Unknown module: " + m);
        return meta;
    }

    private Object clean(Object v) {
        return (v == null || v.toString().isBlank()) ? null : v;
    }

    private Object[] values(Meta meta, Map<String, Object> body) {
        return meta.cols().stream().map(c -> clean(body.get(c))).toArray();
    }

    @GetMapping("/{module}")
    public List<Map<String, Object>> list(@PathVariable String module) {
        Meta m = meta(module);
        return jdbc.queryForList("SELECT * FROM " + m.table() + " ORDER BY " + m.pk() + " DESC");
    }

    @PostMapping("/{module}")
    public Map<String, String> add(@PathVariable String module, @RequestBody Map<String, Object> body) {
        Meta m = meta(module);
        String marks = String.join(",", Collections.nCopies(m.cols().size(), "?"));
        jdbc.update("INSERT INTO " + m.table() + " (" + String.join(",", m.cols()) + ") VALUES (" + marks + ")", values(m, body));
        return Map.of("status", "added");
    }

    @PutMapping("/{module}/{id}")
    public Map<String, String> update(@PathVariable String module, @PathVariable int id, @RequestBody Map<String, Object> body) {
        Meta m = meta(module);
        String set = String.join(",", m.cols().stream().map(c -> c + "=?").toList());
        List<Object> params = new ArrayList<>(Arrays.asList(values(m, body)));
        params.add(id);
        jdbc.update("UPDATE " + m.table() + " SET " + set + " WHERE " + m.pk() + "=?", params.toArray());
        return Map.of("status", "updated");
    }

    @DeleteMapping("/{module}/{id}")
    public Map<String, String> delete(@PathVariable String module, @PathVariable int id) {
        Meta m = meta(module);
        jdbc.update("DELETE FROM " + m.table() + " WHERE " + m.pk() + "=?", id);
        return Map.of("status", "deleted");
    }

    @GetMapping("/reports/summary")
    public Map<String, Object> summary() {
        Map<String, Object> s = new LinkedHashMap<>();
        s.put("Total Cows", jdbc.queryForObject("SELECT COUNT(*) FROM cow", Object.class));
        s.put("Milk Today (L)", jdbc.queryForObject("SELECT COALESCE(SUM(total_qty),0) FROM milk_production WHERE production_date=CURDATE()", Object.class));
        s.put("Total Revenue (Rs)", jdbc.queryForObject("SELECT COALESCE(SUM(total_amount),0) FROM milk_sales", Object.class));
        s.put("Total Expenses (Rs)", jdbc.queryForObject("SELECT COALESCE(SUM(amount),0) FROM expense", Object.class));
        return s;
    }

    @GetMapping("/reports/{name}")
    public List<Map<String, Object>> report(@PathVariable String name) {
        String sql = REPORTS.get(name);
        if (sql == null) throw new IllegalArgumentException("Unknown report: " + name);
        return jdbc.queryForList(sql);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handle(Exception e) {
        String msg = e.getMessage() == null ? "Error" : e.getMessage();
        return ResponseEntity.badRequest().body(Map.of("error", msg));
    }
}
