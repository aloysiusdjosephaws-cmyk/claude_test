package com.example.docmgmt.config;

import com.example.docmgmt.model.HelpDocument;
import com.example.docmgmt.repository.HelpDocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.util.FileCopyUtils;

import java.util.List;

@Component
@RequiredArgsConstructor
public class HelpSeeder implements ApplicationRunner {

    private final HelpDocumentRepository helpRepository;

    private static final List<String> SCREENS = List.of(
            "SUPER_USER", "PROJECT_OFFICER", "APP_MANAGER", "APP_USER");

    @Override
    public void run(ApplicationArguments args) throws Exception {
        for (String screen : SCREENS) {
            if (helpRepository.findByScreenName(screen).isPresent()) {
                continue;
            }
            ClassPathResource resource = new ClassPathResource("help/" + screen + ".html");
            if (!resource.exists()) {
                continue;
            }
            byte[] data = FileCopyUtils.copyToByteArray(resource.getInputStream());
            HelpDocument doc = new HelpDocument();
            doc.setScreenName(screen);
            doc.setDocName(screen + "-help.html");
            doc.setContentType("text/html");
            doc.setData(data);
            doc.setUpdatedBy("system");
            helpRepository.save(doc);
        }
    }
}
