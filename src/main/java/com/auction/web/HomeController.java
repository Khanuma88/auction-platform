package com.auction.web;

import com.auction.service.SystemStatusService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    private final SystemStatusService statusService;

    public HomeController(SystemStatusService statusService) {
        this.statusService = statusService;
    }

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("status", statusService.currentStatus());
        return "index";
    }
}
